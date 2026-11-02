package cfu.group.plan

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.media.RingtoneManager
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * پل کوچک به تنظیمات باتری اندروید.
 *
 * هدف: آلارم‌ها روی گوشی‌هایی که اپ را در پس‌زمینه می‌خوابانند
 * (شیائومی/ردمی، هواوی، سامسونگ، اوپو، ویوو…) هم سر وقت بیایند.
 * اپ خودش هیچ کاری نمی‌کند؛ فقط صفحهٔ درستِ تنظیمات را برای کاربر باز می‌کند.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "cfu.group.plan/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "openBatteryOptimizationSettings" -> result.success(openBatteryOptimizationSettings())
                    "openAutoStartSettings" -> result.success(openAutoStartSettings())
                    "openAppSettings" -> result.success(openAppSettings())
                    "deviceInfo" -> result.success(deviceInfo())
                    "appAlarmSoundUri" -> result.success(AlarmSounds.appAlarmUri(this))
                    "systemSoundUri" -> result.success(AlarmSounds.systemSoundUri(this))
                    "customSoundUri" -> {
                        val raw = call.argument<String>("uri")
                        result.success(AlarmSounds.customSoundUri(this, raw))
                    }
                    "pickCustomSound" -> {
                        pendingSoundResult = result
                        openRingtonePicker()
                    }
                    "persistedCustomSoundUri" -> result.success(AlarmSounds.persistedCustomUri(this))
                    "soundDisplayName" -> {
                        val raw = call.argument<String>("uri")
                        result.success(AlarmSounds.displayName(this, raw))
                    }
                    "clearCustomSound" -> {
                        AlarmSounds.clearPersisted(this)
                        result.success(true)
                    }
                    "previewSound" -> {
                        val raw = call.argument<String>("uri")
                        result.success(previewSound(raw))
                    }
                    "stopPreview" -> {
                        stopPreview()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /** صفحهٔ «بهینه‌سازی باتری» — کاربر خودش این اپ را استثنا می‌کند. */
    private fun openBatteryOptimizationSettings(): Boolean {
        val candidates = listOf(
            // صفحهٔ مستقیم درخواست استثنا برای همین اپ
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .setData(Uri.parse("package:$packageName")),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS),
            // آخرین راه: صفحهٔ تنظیمات خود اپ
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName")),
        )
        return launchFirst(candidates)
    }

    /**
     * صفحهٔ Autostart سازنده‌ها. هر گوشی نام و اکشن خودش را دارد و هیچ API
     * رسمی‌ای وجود ندارد؛ پس همه را به ترتیب امتحان می‌کنیم و اگر هیچ‌کدام
     * نبود، صفحهٔ تنظیمات اپ باز می‌شود.
     */
    private fun openAutoStartSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val candidates = mutableListOf<Intent>()

        fun component(pkg: String, cls: String) =
            Intent().apply {
                setClassName(pkg, cls)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

        when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                candidates += component(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                )
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                candidates += component(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                )
                candidates += component(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity",
                )
            }
            manufacturer.contains("samsung") -> {
                // مسیر واقعی سامسونگ: Battery and device care → Battery
                candidates += component(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                )
                candidates += component(
                    "com.samsung.android.sm",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                )
                candidates += component(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.backgroundlimit.BatteryBackgroundLimitActivity",
                )
                candidates += component(
                    "com.samsung.android.sm",
                    "com.samsung.android.sm.ui.battery.backgroundlimit.BatteryBackgroundLimitActivity",
                )
                // صفحهٔ «محدودیت استفاده در پس‌زمینه» در اندروید ۱۳+ سامسونگ
                candidates += Intent("com.samsung.android.sm.ACTION_BATTERY")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                candidates += component(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.devicecare.DeviceCareActivity",
                )
            }
            manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus") -> {
                candidates += component(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                )
                candidates += component(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.startupapp.StartupAppListActivity",
                )
            }
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                candidates += component(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                )
                candidates += component(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
                )
            }
            manufacturer.contains("asus") -> {
                candidates += component(
                    "com.asus.mobilemanager",
                    "com.asus.mobilemanager.autostart.AutoStartActivity",
                )
            }
            manufacturer.contains("letv") || manufacturer.contains("leeco") -> {
                candidates += component(
                    "com.letv.android.letvsafe",
                    "com.letv.android.letvsafe.AutobootManageActivity",
                )
            }
            manufacturer.contains("nokia") -> {
                candidates += component(
                    "com.evenwell.powersaving.g3",
                    "com.evenwell.powersaving.g3.exception.PowerSaverExceptionActivity",
                )
            }
        }

        // اگر هیچ صفحهٔ مخصوص سازنده‌ای پیدا نشد، از باز کردن «تنظیمات اپ»
        // خودداری می‌کنیم: کاربر را به صفحه‌ای می‌برد که هیچ ربطی به Autostart
        // ندارد و فقط گیج می‌شود. به‌جایش false برمی‌گردانیم تا اپ راهنمای
        // گام‌به‌گام فارسی نشان بدهد.
        return launchFirst(candidates)
    }

    private fun openAppSettings(): Boolean {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:$packageName"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ── انتخابگر رسمی زنگ اندروید ──
    // چرا این روش: URI فایل (file://) برای SystemUI قابل خواندن نیست و اعلان
    // بی‌صدا می‌شود. انتخابگر زنگ یک URI پایدار content:// می‌دهد که همیشه
    // خواندنی است و کاربر می‌تواند از موسیقی‌های خودش هم انتخاب کند.
    private var pendingSoundResult: MethodChannel.Result? = null

    private val ringtoneRequestCode = 4201

    private fun openRingtonePicker() {
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            // اگر قبلاً صدایی انتخاب شده بود، در لیست انتخاب‌شده باشد
            val current = AlarmSounds.persistedCustomUri(this@MainActivity)
            if (current != null) {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
            }
        }
        try {
            startActivityForResult(intent, ringtoneRequestCode)
        } catch (e: Exception) {
            pendingSoundResult?.success(null)
            pendingSoundResult = null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == ringtoneRequestCode) {
            var uri: String? = null
            if (resultCode == RESULT_OK && data != null) {
                // getParcelableExtra<T> فقط از API 33 هست؛ نسخهٔ قدیمی روی
                // اندروید ۱۳ و پایین‌تر کرش می‌کند.
                @Suppress("DEPRECATION")
                val picked = if (android.os.Build.VERSION.SDK_INT >= 33) {
                    data.getParcelableExtra(
                        RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java,
                    )
                } else {
                    data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI) as? Uri
                }
                if (picked != null) {
                    uri = picked.toString()
                    // دسترسی خواندن ماندگار (برای محتوای کاربر)
                    try {
                        contentResolver.takePersistableUriPermission(
                            picked,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION,
                        )
                    } catch (e: Exception) {
                        // بعضی URIها قابل persist نیستند ولی خواندنی‌اند
                    }
                    AlarmSounds.persistCustom(this, uri)
                }
            }
            pendingSoundResult?.success(uri)
            pendingSoundResult = null
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    // ── پخش نمونهٔ صدا برای انتخاب کاربر ──
    private var previewRingtone: android.media.Ringtone? = null

    /** یک بار پخش می‌کند تا کاربر صدا را بشنود. */
    private fun previewSound(uriString: String?): Boolean {
        stopPreview()
        val uri = try {
            Uri.parse(uriString ?: return false)
        } catch (e: Exception) {
            return false
        }
        return try {
            val r = RingtoneManager.getRingtone(this, uri) ?: return false
            // پیش‌فرض Ringtone لوپ می‌کند و تا ابد پخش می‌شد
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                r.isLooping = false
            }
            r.play()
            previewRingtone = r
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun stopPreview() {
        try {
            previewRingtone?.stop()
        } catch (e: Exception) {
            // بی‌خیال
        }
        previewRingtone = null
    }

    override fun onDestroy() {
        stopPreview()
        super.onDestroy()
    }

    /**
     * اولین اکتیویتی که واقعاً روی این گوشی هست را باز می‌کند.
     *
     * نکتهٔ مهم: `resolveActivity` با PackageManager های سخت‌گیر (اندروید ۱۱+)
     * برای اکتیویتی‌های پکیج‌های دیگر ممکن است null برگرداند حتی وقتی اکتیویتی
     * وجود دارد. پس هم resolveActivity را چک می‌کنیم هم خودِ startActivity را
     * در try/catch صدا می‌زنیم.
     */
    private fun launchFirst(intents: List<Intent>): Boolean {
        for (raw in intents) {
            val intent = Intent(raw).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                // اگر resolve موفق بود، مستقیم باز کن
                val resolved = intent.resolveActivity(packageManager)
                if (resolved != null) {
                    startActivity(intent)
                    return true
                }
            } catch (e: Exception) {
                // ادامه بده
            }
            try {
                // حتی اگر resolve null داد، ممکن است باز شود (محدودیت PackageManager)
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // این صفحه روی این گوشی نیست → بعدی
            }
        }
        return false
    }

    /** برای متن راهنما: نام سازنده و نسخهٔ اندروید */
    private fun deviceInfo(): Map<String, Any> = mapOf(
        "manufacturer" to Build.MANUFACTURER,
        "brand" to Build.BRAND,
        "model" to Build.MODEL,
        "sdk" to Build.VERSION.SDK_INT,
    )
}
