package com.fladroid.tracker

import android.content.*
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.database.sqlite.SQLiteDatabase

import java.text.SimpleDateFormat
import java.util.*

/**
 * Tracker Content Provider — lokalni API za medjuaplikacijsku komunikaciju.
 *
 * Authority: com.fladroid.tracker.provider
 *
 * URI-ji:
 *   content://com.fladroid.tracker.provider/values
 *       query -> sve vrijednosti za danas
 *
 *   content://com.fladroid.tracker.provider/values/{button_id}
 *       query  -> vrijednost jednog gumba za danas
 *       update -> promijeni vrijednost (ContentValues: delta = +1 ili -1)
 *
 * Kolone u rezultatu: button_id TEXT | date TEXT | value INTEGER
 *
 * Pristup se moze ukljuciti/iskljuciti iz Tracker Settings ekrana.
 * Ako je iskljucen, sve operacije vracaju prazan rezultat.
 */
class TrackerProvider : ContentProvider() {

    companion object {
        const val AUTHORITY = "com.fladroid.tracker.provider"
        const val DB_NAME   = "tracker_v2.db"
        const val PREFS_NAME   = "FlutterSharedPreferences"
        const val PREF_KEY     = "flutter.external_access"

        val URI_VALUES: Uri = Uri.parse("content://$AUTHORITY/values")

        private val uriMatcher = UriMatcher(UriMatcher.NO_MATCH).apply {
            addURI(AUTHORITY, "values",   1)
            addURI(AUTHORITY, "values/*", 2)
        }

        private fun todayKey(): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    private lateinit var db: SQLiteDatabase

    override fun onCreate(): Boolean {
        return try {
            val dbPath = context!!.getDatabasePath(DB_NAME)
            db = SQLiteDatabase.openDatabase(
                dbPath.absolutePath, null,
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY
            )
            true
        } catch (e: Exception) { false }
    }

    // Provjeri da li je korisnik ukljucio vanjski pristup u Settings-u
    private fun isAccessEnabled(): Boolean {
        val prefs = context?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs?.getBoolean(PREF_KEY, false) ?: false
    }

    override fun query(
        uri: Uri, projection: Array<String>?, selection: String?,
        selectionArgs: Array<String>?, sortOrder: String?
    ): Cursor {
        val cursor = MatrixCursor(arrayOf("button_id", "date", "value"))
        if (!isAccessEnabled()) return cursor  // pristup iskljucen

        val today = todayKey()
        when (uriMatcher.match(uri)) {
            1 -> {
                val c = db.rawQuery(
                    "SELECT button_id, date, value FROM daily_values WHERE date = ?",
                    arrayOf(today))
                while (c.moveToNext()) {
                    cursor.addRow(arrayOf(c.getString(0), c.getString(1), c.getInt(2)))
                }
                c.close()
            }
            2 -> {
                val buttonId = uri.lastPathSegment ?: return cursor
                val c = db.rawQuery(
                    "SELECT button_id, date, value FROM daily_values WHERE button_id = ? AND date = ?",
                    arrayOf(buttonId, today))
                if (c.moveToFirst()) {
                    cursor.addRow(arrayOf(c.getString(0), c.getString(1), c.getInt(2)))
                } else {
                    cursor.addRow(arrayOf(buttonId, today, 0))
                }
                c.close()
            }
        }
        return cursor
    }

    override fun update(
        uri: Uri, values: ContentValues?, selection: String?,
        selectionArgs: Array<String>?
    ): Int {
        if (!isAccessEnabled()) return 0  // pristup iskljucen
        if (uriMatcher.match(uri) != 2) return 0

        val buttonId = uri.lastPathSegment ?: return 0
        val delta    = values?.getAsInteger("delta") ?: return 0
        val today    = todayKey()

        val c = db.rawQuery(
            "SELECT value FROM daily_values WHERE button_id = ? AND date = ?",
            arrayOf(buttonId, today))
        val current = if (c.moveToFirst()) c.getInt(0) else 0
        c.close()

        val newValue = (current + delta).coerceIn(0, 999)

        val cv = ContentValues().apply {
            put("button_id", buttonId)
            put("date", today)
            put("value", newValue)
        }
        db.insertWithOnConflict("daily_values", null, cv, SQLiteDatabase.CONFLICT_REPLACE)

        val logCv = ContentValues().apply {
            put("timestamp", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date()))
            put("type", "counter")
            put("button_id", buttonId)
            put("delta", delta)
            put("deleted", 0)
        }
        db.insert("log", null, logCv)

        context?.contentResolver?.notifyChange(uri, null)
        return 1
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0
    override fun getType(uri: Uri): String = "vnd.android.cursor.dir/vnd.$AUTHORITY.values"
}
