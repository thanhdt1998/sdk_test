package vn.vietmap.vietmapsdk.testapp.model.customlayer;

import androidx.annotation.Keep;

@Keep
public class ExampleCustomLayer {
  static {
    System.loadLibrary("example-custom-layer");
  }

  public static native long createContext();

  public static native void setColor(float red, float green, float blue, float alpha);

  public static long InitializeFunction;
  public static long RenderFunction;
  public static long ContextLostFunction;
  public static long DeinitializeFunction;
}
