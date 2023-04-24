package vn.vietmap.vietmapsdk.testapp.activity.camera

import android.os.Bundle
import android.view.MenuItem
import android.view.View
import android.widget.SeekBar
import android.widget.SeekBar.OnSeekBarChangeListener
import android.widget.TextView
import androidx.annotation.StringRes
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.Toolbar
import androidx.core.content.ContextCompat
import com.google.android.material.floatingactionbutton.FloatingActionButton
import vn.vietmap.vietmapsdk.maps.MapView
import vn.vietmap.vietmapsdk.maps.VietmapMap
import vn.vietmap.vietmapsdk.maps.OnMapReadyCallback
import vn.vietmap.vietmapsdk.maps.Style
import vn.vietmap.vietmapsdk.testapp.R

/**
 * Test activity showcasing using the scrollBy Camera API by moving x,y pixels above Grenada, Spain.
 */
class ScrollByActivity : AppCompatActivity(),
    vn.vietmap.vietmapsdk.maps.OnMapReadyCallback {
    private lateinit var mapView: vn.vietmap.vietmapsdk.maps.MapView
    private lateinit var mapboxMap: vn.vietmap.vietmapsdk.maps.VietmapMap
    private lateinit var seekBarX: SeekBar
    private lateinit var seekBarY: SeekBar
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scroll_by)
        val toolbar = findViewById<Toolbar>(R.id.toolbar)
        setSupportActionBar(toolbar)
        val actionBar = supportActionBar
        if (actionBar != null) {
            actionBar.setDisplayHomeAsUpEnabled(true)
            actionBar.setDisplayShowHomeEnabled(true)
        }
        seekBarX = findViewById(R.id.seekbar_move_x)
        val textViewX = findViewById<TextView>(R.id.textview_x)
        seekBarX.setOnSeekBarChangeListener(
            PixelBarChangeListener(textViewX, R.string.scrollby_x_value)
        )
        seekBarY = findViewById(R.id.seekbar_move_y)
        val textViewY = findViewById<TextView>(R.id.textview_y)
        seekBarY.setOnSeekBarChangeListener(
            PixelBarChangeListener(textViewY, R.string.scrollby_y_value)
        )
        mapView = findViewById(R.id.mapView)
        mapView.setTag(true)
        mapView.onCreate(savedInstanceState)
        mapView.getMapAsync(this)
    }

    override fun onMapReady(map: vn.vietmap.vietmapsdk.maps.VietmapMap) {
        mapboxMap = map
        mapboxMap!!.setStyle(vn.vietmap.vietmapsdk.maps.Style.getPredefinedStyle("Pastel"))
        val uiSettings = mapboxMap!!.uiSettings
        uiSettings.isLogoEnabled = false
        uiSettings.isAttributionEnabled = false
        val fab = findViewById<FloatingActionButton>(R.id.fab)
        fab.setColorFilter(ContextCompat.getColor(this@ScrollByActivity, R.color.primary))
        fab.setOnClickListener { view: View? ->
            mapboxMap!!.scrollBy(
                (seekBarX!!.progress * MULTIPLIER_PER_PIXEL).toFloat(),
                (seekBarY!!.progress * MULTIPLIER_PER_PIXEL).toFloat()
            )
        }
    }

    override fun onStart() {
        super.onStart()
        mapView!!.onStart()
    }

    override fun onResume() {
        super.onResume()
        mapView!!.onResume()
    }

    override fun onPause() {
        super.onPause()
        mapView!!.onPause()
    }

    override fun onStop() {
        super.onStop()
        mapView!!.onStop()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        mapView!!.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        super.onDestroy()
        mapView!!.onDestroy()
    }

    override fun onLowMemory() {
        super.onLowMemory()
        mapView!!.onLowMemory()
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                onBackPressed()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private class PixelBarChangeListener
    internal constructor(
        private val valueView: TextView,
        @field:StringRes @param:StringRes
        private val prefixTextResource: Int
    ) : OnSeekBarChangeListener {
        override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
            val value = progress * MULTIPLIER_PER_PIXEL
            valueView.text = String.format(seekBar.resources.getString(prefixTextResource), value)
        }

        override fun onStartTrackingTouch(seekBar: SeekBar) {}
        override fun onStopTrackingTouch(seekBar: SeekBar) {}
    }

    companion object {
        const val MULTIPLIER_PER_PIXEL = 50
    }
}