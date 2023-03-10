package vn.vietmap.vietmapsdk.testapp.activity.espresso;

import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;

import vn.vietmap.vietmapsdk.maps.MapView;
import vn.vietmap.vietmapsdk.maps.VietmapMap;
import vn.vietmap.vietmapsdk.testapp.R;

/**
 * Base activity for instrumentation testing.
 */
public class EspressoTestActivity extends AppCompatActivity {

  public MapView mapView;
  protected VietmapMap VietmapMap;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_espresso_test);
    mapView = findViewById(R.id.mapView);
    mapView.onCreate(savedInstanceState);
  }

  @Override
  public void onResume() {
    super.onResume();
    mapView.onResume();
  }

  @Override
  protected void onStart() {
    super.onStart();
    mapView.onStart();
  }

  @Override
  public void onPause() {
    super.onPause();
    mapView.onPause();
  }

  @Override
  protected void onStop() {
    super.onStop();
    mapView.onStop();
  }

  @Override
  protected void onSaveInstanceState(Bundle outState) {
    super.onSaveInstanceState(outState);
    mapView.onSaveInstanceState(outState);
  }

  @Override
  protected void onDestroy() {
    super.onDestroy();
    mapView.onDestroy();
  }

  @Override
  public void onLowMemory() {
    super.onLowMemory();
    mapView.onLowMemory();
  }
}
