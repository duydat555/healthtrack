package vn.edu.vku.healthtrack.activity_sensors

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Tác vụ nền định kỳ: đọc bộ đếm bước một lần rồi ghi vào [StepStore]. */
class StepSampleWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val manager = applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return Result.success()
        val latch = CountDownLatch(1)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                StepStore.record(applicationContext, event.values[0].toLong())
                latch.countDown()
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        return try {
            manager.registerListener(
                listener, sensor, SensorManager.SENSOR_DELAY_NORMAL, Handler(Looper.getMainLooper()),
            )
            latch.await(10, TimeUnit.SECONDS)
            Result.success()
        } catch (e: SecurityException) {
            // Người dùng đã thu hồi quyền hoạt động thể chất
            Result.success()
        } finally {
            manager.unregisterListener(listener)
        }
    }
}
