package com.example.zmusic

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.*
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import android.app.PendingIntent

class HomeScreenWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val density = context.resources.displayMetrics.density
        // Redondeo de 16dp convertido a pixels
        val cornerRadius = 16 * density 

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.music_widget).apply {
                val title = widgetData.getString("title", "No hay música")
                val artist = widgetData.getString("artist", "Selecciona una canción")
                val isPlaying = widgetData.getBoolean("is_playing", false)
                val artworkPath = widgetData.getString("artwork_path", null)

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_artist, artist)

                // Cargar Artwork con Bordes Redondeados
                if (artworkPath != null) {
                    val file = File(artworkPath)
                    if (file.exists()) {
                        val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                        if (bitmap != null) {
                            val roundedBitmap = getRoundedCornerBitmap(bitmap, cornerRadius) 
                            setImageViewBitmap(R.id.widget_artwork, roundedBitmap)
                        }
                    }
                } else {
                    setImageViewResource(R.id.widget_artwork, R.drawable.notification_placeholder)
                }

                // Actualizar icono de play/pause
                setImageViewResource(
                    R.id.widget_play_pause,
                    if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play
                )

                // USAR EVENTOS DE MEDIOS NATIVOS
                // Esto envía la orden directamente al AudioService de Flutter de forma eficiente
                
                setOnClickPendingIntent(R.id.widget_play_pause, createMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                setOnClickPendingIntent(R.id.widget_next, createMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT))
                setOnClickPendingIntent(R.id.widget_prev, createMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                
                // Abrir la app al tocar el fondo o la carátula
                val launchIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_container, launchIntent)
                setOnClickPendingIntent(R.id.widget_artwork, launchIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    // Crea un Intent de botón multimedia que Android entrega al AudioService
    private fun createMediaButtonIntent(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON)
        intent.setPackage(context.packageName)
        intent.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        
        return PendingIntent.getBroadcast(
            context, 
            keyCode, 
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun getRoundedCornerBitmap(bitmap: Bitmap, pixels: Float): Bitmap {
        val output = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint()
        val rect = Rect(0, 0, bitmap.width, bitmap.height)
        val rectF = RectF(rect)
        paint.isAntiAlias = true
        canvas.drawARGB(0, 0, 0, 0)
        paint.color = -0xbdbdbe
        canvas.drawRoundRect(rectF, pixels, pixels, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(bitmap, rect, rect, paint)
        return output
    }
}
