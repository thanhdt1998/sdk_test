package vn.vietmap.vietmapsdk.testapp.activity.maplayout

import android.os.Bundle
import android.os.Handler
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import vn.vietmap.vietmapsdk.camera.CameraUpdateFactory
import vn.vietmap.vietmapsdk.geometry.LatLng
// import com.mapbox.vietmapsdk.maps.* //
import vn.vietmap.vietmapsdk.testapp.R

/**
 * Test activity showcasing visibility changes to the mapview.
 */
class VisibilityChangeActivity : AppCompatActivity() {
    private lateinit var mapView: vn.vietmap.vietmapsdk.maps.MapView
    private var mapboxMap: vn.vietmap.vietmapsdk.maps.VietmapMap? = null
    private val handler = Handler()
    private var runnable: Runnable? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_map_visibility)
        mapView = findViewById(R.id.mapView)
        mapView.onCreate(savedInstanceState)
        mapView.getMapAsync(
            vn.vietmap.vietmapsdk.maps.OnMapReadyCallback { map: vn.vietmap.vietmapsdk.maps.VietmapMap? ->
                mapboxMap = map
                mapboxMap!!.setStyle(
                    vn.vietmap.vietmapsdk.maps.Style.getPredefinedStyle(
                        "Streets"
                    )
                )
                mapboxMap!!.animateCamera(
                    vn.vietmap.vietmapsdk.camera.CameraUpdateFactory.newLatLngZoom(
                        vn.vietmap.vietmapsdk.geometry.LatLng(
                            55.754020,
                            37.620948
                        ),
                        12.0
                    ),
                    9000
                )
            }
        )
    }

    override fun onStart() {
        super.onStart()
        mapView!!.onStart()
        handler.post(
            VisibilityRunner(
                mapView,
                findViewById(R.id.viewParent),
                handler
            ).also { runnable = it }
        )
    }

    override fun onResume() {
        super.onResume()
        mapView!!.onResume()
    }

    private class VisibilityRunner internal constructor(
        private val mapView: vn.vietmap.vietmapsdk.maps.MapView?,
        private val viewParent: View?,
        private val handler: Handler
    ) : Runnable {
        private var currentStep = 0
        override fun run() {
            if (isViewHiearchyReady) {
                if (isEvenStep) {
                    viewParent!!.visibility = View.VISIBLE
                    mapView!!.visibility = View.VISIBLE
                } else if (isFirstOrThirdStep) {
                    mapView!!.visibility = visibilityForStep
                } else if (isFifthOrSeventhStep) {
                    viewParent!!.visibility = visibilityForStep
                }
                updateStep()
            }
            handler.postDelayed(this, 1500)
        }

        private fun updateStep() {
            if (currentStep == 7) {
                currentStep = 0
            } else {
                currentStep++
            }
        }

        private val visibilityForStep: Int
            private get() = if (currentStep == 1 || currentStep == 5) View.GONE else View.INVISIBLE
        private val isFifthOrSeventhStep: Boolean
            private get() = currentStep == 5 || currentStep == 7
        private val isFirstOrThirdStep: Boolean
            private get() = currentStep == 1 || currentStep == 3
        private val isEvenStep: Boolean
            private get() = currentStep == 0 || currentStep % 2 == 0
        private val isViewHiearchyReady: Boolean
            private get() = mapView != null && viewParent != null
    }

    override fun onPause() {
        super.onPause()
        mapView!!.onPause()
    }

    override fun onStop() {
        super.onStop()
        if (runnable != null) {
            handler.removeCallbacks(runnable!!)
            runnable = null
        }
        mapView!!.onStop()
    }

    override fun onLowMemory() {
        super.onLowMemory()
        mapView!!.onLowMemory()
    }

    override fun onDestroy() {
        super.onDestroy()
        mapView!!.onDestroy()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        mapView!!.onSaveInstanceState(outState)
    }
}
