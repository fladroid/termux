package com.fladroid.tracker

import android.content.*
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.text.SimpleDateFormat
import java.util.*

/**
 * Tracker Content Provider
 *
 * Omogucava citanje i pisanje Tracker dnevnih vrijednosti
 * bez mreze, samo lokalno na istom Android uredjaju.
 *
 * Authority: com.fladroid.tracker.provider
 *
 * URI-ji:
 *   content://com.fladroid.tracker.provider/values
 *       GET (query) - sve vrijednosti za danas
 *
 *   content://com.fladroid.tracker.provider/values/{button_id}
 *       GET (query) - vrijednost jednog gumba za danas
 *       POST (update) - promijeni vrijednost
 *           ContentValues: delta = +1 ili -1
 *
 * Kolone u rezultatu:
 *   button_id  TEXT
 *   date       TEXT  (yyyy-MM-dd)
 *   value      INTEGER
 */
class TrackerProvider : ContentProvider() {

    companion object {
        const val AUTHORITY = "com.fladroid.tracker.provider"
        const val DB_NAME   = "tracker_v2.db"

        val URI_VALUES: Uri = Uri.parse("content://$AUTHORITY/values")

        private val uriMatcher = UriMatcher(UriMatcher.NO_MATCH).apply {
            addURI(AUTHORITY, "values",       1)  // sve vrijednosti
            addURI(AUTHORITY, "values/*",     2)  // jedan button_id
        }

        private fun todayKey(): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    // Direktan pristup SQLite bazi koju Flutter/sqflite koristi
    private lateinit var db: SQLiteDatabase

    override fun onCreate(): Boolean {
        try {
            val dbPath = context!!.getDatabasePath(DB_NAME)
            db = SQLiteDatabase.openDatabase(
                dbPath.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY
            )
        } catch (e: Exception) {
            return false
        }
        return true
    }

    override fun query(
        uri: Uri, projection: Array<String>?, selection: String?,
        selectionArgs: Array<String>?, sortOrder: String?
    ): Cursor {
        val cursor = MatrixCursor(arrayOf("button_id", "date", "value"))
        val today  = todayKey()

        when (uriMatcher.match(uri)) {
            1 -> {
                // Sve vrijednosti za danas
                val c = db.rawQuery(
                    "SELECT button_id, date, value FROM daily_values WHERE date = ?",
                    arrayOf(today)
                )
                while (c.moveToNext()) {
                    cursor.addRow(arrayOf(
                        c.getString(0), c.getString(1), c.getInt(2)
                    ))
                }
                c.close()
            }
            2 -> {
                // Jedan button_id za danas
                val buttonId = uri.lastPathSegment ?: return cursor
                val c = db.rawQuery(
                    "SELECT button_id, date, value FROM daily_values WHERE button_id = ? AND date = ?",
                    arrayOf(buttonId, today)
                )
                if (c.moveToFirst()) {
                    cursor.addRow(arrayOf(
                        c.getString(0), c.getString(1), c.getInt(2)
                    ))
                } else {
                    // Gumb postoji ali nema unosa za danas - vrati 0
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
        if (uriMatcher.match(uri) != 2) return 0
        val buttonId = uri.lastPathSegment ?: return 0
        val delta    = values?.getAsInteger("delta") ?: return 0
        val today    = todayKey()

        // Citaj trenutnu vrijednost
        val c = db.rawQuery(
            "SELECT value FROM daily_values WHERE button_id = ? AND date = ?",
            arrayOf(buttonId, today)
        )
        val current = if (c.moveToFirst()) c.getInt(0) else 0
        c.close()

        val newValue = (current + delta).coerceIn(0, 999)

        // Upsert u daily_values
        val cv = ContentValues().apply {
            put("button_id", buttonId)
            put("date", today)
            put("value", newValue)
        }
        db.insertWithOnConflict("daily_values", null, cv, SQLiteDatabase.CONFLICT_REPLACE)

        // Log unos
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

    // Insert i delete nisu podrzani - Tracker je jedini vlasnik podataka
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int = 0
    override fun getType(uri: Uri): String = "vnd.android.cursor.dir/vnd.$AUTHORITY.values"
}
