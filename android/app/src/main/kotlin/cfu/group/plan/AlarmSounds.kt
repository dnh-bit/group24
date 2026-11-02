package cfu.group.plan

import android.content.Context
import android.media.RingtoneManager
import android.net.Uri

/**
 * صداهای آلارم.
 *
 * چرا لازم است: اندروید صدا را روی «کانال اعلان» تنظیم می‌کند و صدای کانال
 * را بعد از ساخت هم نمی‌شود عوض کرد. برای همین برای هر انتخاب صدا یک کانال
 * جدا می‌سازیم و URI درست را از این‌جا می‌گیریم.
 *
 * نکتهٔ مهم (باگ قبلی): اگر صدا را خالی بگذاریم، پلاگین به
 * `RingtoneManager.getDefaultUri(TYPE_NOTIFICATION)` تکیه می‌کند که روی
 * بعضی گوشی‌ها null برمی‌گرداند و کانال کامل بی‌صدا ساخته می‌شود. پس همیشه
 * یک URI مشخص می‌دهیم.
 */
object AlarmSounds {
    /** زنگ اختصاصی خود برنامه (android/app/src/main/res/raw/alarm.ogg) */
    fun appAlarmUri(context: Context): String =
        "android.resource://${context.packageName}/raw/alarm"

    /** صدای اعلان پیش‌فرض گوشی، با چند مسیر جانشین */
    fun systemSoundUri(context: Context): String {
        val candidates = listOf(
            RingtoneManager.TYPE_NOTIFICATION,
            RingtoneManager.TYPE_ALARM,
            RingtoneManager.TYPE_RINGTONE,
        )
        for (type in candidates) {
            val uri: Uri? = RingtoneManager.getDefaultUri(type)
            if (uri != null && uri.toString().isNotEmpty()) return uri.toString()
        }
        // آخرین راه: صدای خود برنامه (تا هرگز بی‌صدا نشود)
        return appAlarmUri(context)
    }

    private const val PREFS = "alarm_sound_prefs"
    private const val KEY_CUSTOM = "custom_uri"

    /** URI موسیقی انتخاب‌شدهٔ کاربر را نگه می‌دارد. */
    fun persistCustom(context: Context, uri: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_CUSTOM, uri).apply()
    }

    fun persistedCustomUri(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_CUSTOM, null)

    fun clearPersisted(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(KEY_CUSTOM).apply()
    }

    /** نام نمایشی صدا برای نشان دادن در تنظیمات. */
    fun displayName(context: Context, uriString: String?): String {
        if (uriString.isNullOrBlank()) return ""
        return try {
            val uri = Uri.parse(uriString)
            val r = RingtoneManager.getRingtone(context, uri)
            r?.getTitle(context) ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    /**
     * صدای انتخاب‌شدهٔ کاربر از فایل‌های گوشی. اگر دسترسی ماندگار نداشته باشیم
     * یا URI معتبر نباشد، null برمی‌گردانیم تا صدای پیش‌فرض استفاده شود.
     */
    fun customSoundUri(context: Context, uriString: String?): String? {
        if (uriString.isNullOrBlank()) return null
        val parsed = try {
            Uri.parse(uriString)
        } catch (e: Exception) {
            return null
        }
        // اگر فایل پاک شده باشد، RingtoneManager متوجه می‌شود
        return try {
            val r = RingtoneManager.getRingtone(context, parsed)
            if (r == null) null else uriString
        } catch (e: Exception) {
            null
        }
    }
}
