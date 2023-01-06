package vn.vietmap.vietmapsdk.maps;

import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Parcel;
import android.os.Parcelable;
import android.text.TextUtils;
import android.util.AttributeSet;
import android.view.Gravity;

import androidx.annotation.ColorInt;
import androidx.annotation.IntRange;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;
import androidx.core.content.res.ResourcesCompat;

import com.mapbox.vietmapsdk.R;
import vn.vietmap.vietmapsdk.camera.CameraPosition;
import vn.vietmap.vietmapsdk.constants.VietmapConstants;
import vn.vietmap.vietmapsdk.utils.BitmapUtils;
import vn.vietmap.vietmapsdk.utils.FontUtils;

import java.util.Arrays;

/**
 * Defines configuration VietmapMapMapOptions for a VietmapMap. These options can be used when adding a
 * map to your application programmatically (as opposed to via XML). If you are using a MapFragment,
 * you can pass these options in using the static factory method newInstance(VietMapOptions).
 * If you are using a MapView, you can pass these options in using the constructor
 * MapView(Context, VietMapOptions). If you add a map using XML, then you can apply these options
 * using custom XML tags.
 */
public class VietMapOptions implements Parcelable {

  private static final int LIGHT_GRAY = 0xFFF0E9E1; // RGB(240, 233, 225))
  private static final float FOUR_DP = 4f;
  private static final float NINETY_TWO_DP = 92f;
  private static final int UNDEFINED_COLOR = -1;

  private CameraPosition cameraPosition;

  private boolean debugActive;

  private boolean compassEnabled = true;
  private boolean fadeCompassFacingNorth = true;
  private int compassGravity = Gravity.TOP | Gravity.END;
  private int[] compassMargins;
  private Drawable compassImage;

  private boolean logoEnabled = false;
  private int logoGravity = Gravity.BOTTOM | Gravity.START;
  private int[] logoMargins;

  @ColorInt
  private int attributionTintColor = UNDEFINED_COLOR;
  private boolean attributionEnabled = true;
  private int attributionGravity = Gravity.BOTTOM | Gravity.START;
  private int[] attributionMargins;

  private double minZoom = VietmapConstants.MINIMUM_ZOOM;
  private double maxZoom = VietmapConstants.MAXIMUM_ZOOM;
  private double minPitch = VietmapConstants.MINIMUM_PITCH;
  private double maxPitch = VietmapConstants.MAXIMUM_PITCH;

  private boolean rotateGesturesEnabled = true;
  private boolean scrollGesturesEnabled = true;
  private boolean horizontalScrollGesturesEnabled = true;
  private boolean tiltGesturesEnabled = true;
  private boolean zoomGesturesEnabled = true;
  private boolean doubleTapGesturesEnabled = true;
  private boolean quickZoomGesturesEnabled = true;

  private boolean prefetchesTiles = true;
  private int prefetchZoomDelta = 4;
  private boolean zMediaOverlay = false;

  private boolean localIdeographFontFamilyEnabled = true;
  private String localIdeographFontFamily;
  private String[] localIdeographFontFamilies;

  private String apiBaseUri;

  private boolean textureMode;
  private boolean translucentTextureSurface;

  @ColorInt
  private int foregroundLoadColor;

  private float pixelRatio;

  private boolean crossSourceCollisions = true;

  /**
   * Creates a new VietMapOptions object.
   *
   * @deprecated Use {@link #createFromAttributes(Context, AttributeSet)} instead.
   */
  @Deprecated
  public VietMapOptions() {
  }

  private VietMapOptions(Parcel in) {
    cameraPosition = in.readParcelable(CameraPosition.class.getClassLoader());
    debugActive = in.readByte() != 0;

    compassEnabled = in.readByte() != 0;
    compassGravity = in.readInt();
    compassMargins = in.createIntArray();
    fadeCompassFacingNorth = in.readByte() != 0;

    Bitmap compassBitmap = in.readParcelable(getClass().getClassLoader());
    if (compassBitmap != null) {
      compassImage = new BitmapDrawable(compassBitmap);
    }

    logoEnabled = in.readByte() != 0;
    logoGravity = in.readInt();
    logoMargins = in.createIntArray();

    attributionEnabled = in.readByte() != 0;
    attributionGravity = in.readInt();
    attributionMargins = in.createIntArray();
    attributionTintColor = in.readInt();

    minZoom = in.readDouble();
    maxZoom = in.readDouble();
    minPitch = in.readDouble();
    maxPitch = in.readDouble();

    rotateGesturesEnabled = in.readByte() != 0;
    scrollGesturesEnabled = in.readByte() != 0;
    horizontalScrollGesturesEnabled = in.readByte() != 0;
    tiltGesturesEnabled = in.readByte() != 0;
    zoomGesturesEnabled = in.readByte() != 0;
    doubleTapGesturesEnabled = in.readByte() != 0;
    quickZoomGesturesEnabled = in.readByte() != 0;

    apiBaseUri = in.readString();
    textureMode = in.readByte() != 0;
    translucentTextureSurface = in.readByte() != 0;
    prefetchesTiles = in.readByte() != 0;
    prefetchZoomDelta = in.readInt();
    zMediaOverlay = in.readByte() != 0;
    localIdeographFontFamilyEnabled = in.readByte() != 0;
    localIdeographFontFamily = in.readString();
    localIdeographFontFamilies = in.createStringArray();
    pixelRatio = in.readFloat();
    foregroundLoadColor = in.readInt();
    crossSourceCollisions = in.readByte() != 0;
  }

  /**
   * Creates a default VietmapMapsOptions from a given context.
   *
   * @param context Context related to a map view.
   * @return the VietMapOptions created from attributes
   */
  @NonNull
  public static VietMapOptions createFromAttributes(@NonNull Context context) {
    return createFromAttributes(context, null);
  }

  /**
   * Creates a VietmapMapsOptions from the attribute set.
   *
   * @param context Context related to a map view.
   * @param attrs   Attributeset containing configuration
   * @return the VietMapOptions created from attributes
   */
  @NonNull
  public static VietMapOptions createFromAttributes(@NonNull Context context, @Nullable AttributeSet attrs) {
    TypedArray typedArray = context.obtainStyledAttributes(attrs, R.styleable.mapbox_MapView, 0, 0);
    return createFromAttributes(new VietMapOptions(), context, typedArray);
  }

  @VisibleForTesting
  static VietMapOptions createFromAttributes(@NonNull VietMapOptions VietmapMapOptions,
                                               @NonNull Context context,
                                               @Nullable TypedArray typedArray) {
    float pxlRatio = context.getResources().getDisplayMetrics().density;
    try {
      VietmapMapOptions.camera(new CameraPosition.Builder(typedArray).build());

      // deprecated
      VietmapMapOptions.apiBaseUrl(typedArray.getString(R.styleable.mapbox_MapView_mapbox_apiBaseUrl));

      String baseUri = typedArray.getString(R.styleable.mapbox_MapView_mapbox_apiBaseUri);
      if (!TextUtils.isEmpty(baseUri)) {
        // override deprecated property if a value of the new type was provided
        VietmapMapOptions.apiBaseUri(baseUri);
      }

      VietmapMapOptions.zoomGesturesEnabled(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiZoomGestures, true));
      VietmapMapOptions.scrollGesturesEnabled(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiScrollGestures, true));
      VietmapMapOptions.horizontalScrollGesturesEnabled(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiHorizontalScrollGestures, true));
      VietmapMapOptions.rotateGesturesEnabled(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiRotateGestures, true));
      VietmapMapOptions.tiltGesturesEnabled(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiTiltGestures, true));
      VietmapMapOptions.doubleTapGesturesEnabled(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiDoubleTapGestures, true));
      VietmapMapOptions.quickZoomGesturesEnabled(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiQuickZoomGestures, true));

      VietmapMapOptions.maxZoomPreference(typedArray.getFloat(R.styleable.mapbox_MapView_mapbox_cameraZoomMax,
        VietmapConstants.MAXIMUM_ZOOM));
      VietmapMapOptions.minZoomPreference(typedArray.getFloat(R.styleable.mapbox_MapView_mapbox_cameraZoomMin,
        VietmapConstants.MINIMUM_ZOOM));
      VietmapMapOptions.maxPitchPreference(typedArray.getFloat(R.styleable.mapbox_MapView_mapbox_cameraPitchMax,
        VietmapConstants.MAXIMUM_PITCH));
      VietmapMapOptions.minPitchPreference(typedArray.getFloat(R.styleable.mapbox_MapView_mapbox_cameraPitchMin,
        VietmapConstants.MINIMUM_PITCH));

      VietmapMapOptions.compassEnabled(typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiCompass, true));
      VietmapMapOptions.compassGravity(typedArray.getInt(R.styleable.mapbox_MapView_mapbox_uiCompassGravity,
        Gravity.TOP | Gravity.END));
      VietmapMapOptions.compassMargins(new int[] {
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiCompassMarginLeft,
          FOUR_DP * pxlRatio)),
        ((int) typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiCompassMarginTop,
          FOUR_DP * pxlRatio)),
        ((int) typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiCompassMarginRight,
          FOUR_DP * pxlRatio)),
        ((int) typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiCompassMarginBottom,
          FOUR_DP * pxlRatio))});
      VietmapMapOptions.compassFadesWhenFacingNorth(typedArray.getBoolean(
        R.styleable.mapbox_MapView_mapbox_uiCompassFadeFacingNorth, true));
      Drawable compassDrawable = typedArray.getDrawable(
        R.styleable.mapbox_MapView_mapbox_uiCompassDrawable);
      if (compassDrawable == null) {
        compassDrawable = ResourcesCompat.getDrawable(context.getResources(), R.drawable.mapbox_compass_icon, null);
      }
      VietmapMapOptions.compassImage(compassDrawable);

      VietmapMapOptions.logoEnabled(typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_uiLogo, true));
      VietmapMapOptions.logoGravity(typedArray.getInt(R.styleable.mapbox_MapView_mapbox_uiLogoGravity,
        Gravity.BOTTOM | Gravity.START));
      VietmapMapOptions.logoMargins(new int[] {
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiLogoMarginLeft,
          FOUR_DP * pxlRatio)),
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiLogoMarginTop,
          FOUR_DP * pxlRatio)),
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiLogoMarginRight,
          FOUR_DP * pxlRatio)),
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiLogoMarginBottom,
          FOUR_DP * pxlRatio))});

      VietmapMapOptions.attributionTintColor(typedArray.getColor(
        R.styleable.mapbox_MapView_mapbox_uiAttributionTintColor, UNDEFINED_COLOR));
      VietmapMapOptions.attributionEnabled(typedArray.getBoolean(
        R.styleable.mapbox_MapView_mapbox_uiAttribution, true));
      VietmapMapOptions.attributionGravity(typedArray.getInt(
        R.styleable.mapbox_MapView_mapbox_uiAttributionGravity, Gravity.BOTTOM | Gravity.START));
      VietmapMapOptions.attributionMargins(new int[] {
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiAttributionMarginLeft,
          NINETY_TWO_DP * pxlRatio)),
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiAttributionMarginTop,
          FOUR_DP * pxlRatio)),
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiAttributionMarginRight,
          FOUR_DP * pxlRatio)),
        (int) (typedArray.getDimension(R.styleable.mapbox_MapView_mapbox_uiAttributionMarginBottom,
          FOUR_DP * pxlRatio))});
      VietmapMapOptions.textureMode(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_renderTextureMode, false));
      VietmapMapOptions.translucentTextureSurface(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_renderTextureTranslucentSurface, false));
      VietmapMapOptions.setPrefetchesTiles(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_enableTilePrefetch, true));
      VietmapMapOptions.setPrefetchZoomDelta(
        typedArray.getInt(R.styleable.mapbox_MapView_mapbox_prefetchZoomDelta, 4));
      VietmapMapOptions.renderSurfaceOnTop(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_enableZMediaOverlay, false));

      VietmapMapOptions.localIdeographFontFamilyEnabled =
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_localIdeographEnabled, true);

      int localIdeographFontFamiliesResId =
        typedArray.getResourceId(R.styleable.mapbox_MapView_mapbox_localIdeographFontFamilies, 0);
      if (localIdeographFontFamiliesResId != 0) {
        String[] localIdeographFontFamilies =
          context.getResources().getStringArray(localIdeographFontFamiliesResId);
        VietmapMapOptions.localIdeographFontFamily(localIdeographFontFamilies);
      } else {
        // did user provide xml font string?
        String localIdeographFontFamily =
          typedArray.getString(R.styleable.mapbox_MapView_mapbox_localIdeographFontFamily);
        if (localIdeographFontFamily == null) {
          localIdeographFontFamily = VietmapConstants.DEFAULT_FONT;
        }
        VietmapMapOptions.localIdeographFontFamily(localIdeographFontFamily);
      }

      VietmapMapOptions.pixelRatio(
        typedArray.getFloat(R.styleable.mapbox_MapView_mapbox_pixelRatio, 0));
      VietmapMapOptions.foregroundLoadColor(
        typedArray.getInt(R.styleable.mapbox_MapView_mapbox_foregroundLoadColor, LIGHT_GRAY)
      );
      VietmapMapOptions.crossSourceCollisions(
        typedArray.getBoolean(R.styleable.mapbox_MapView_mapbox_cross_source_collisions, true)
      );
    } finally {
      typedArray.recycle();
    }
    return VietmapMapOptions;
  }

  /**
   * Specifies the URL used for API endpoint.
   *
   * @param apiBaseUrl The base of our API endpoint
   * @return This
   * @deprecated use {@link #apiBaseUri} instead
   */
  @Deprecated
  @NonNull
  public VietMapOptions apiBaseUrl(String apiBaseUrl) {
    this.apiBaseUri = apiBaseUrl;
    return this;
  }

  /**
   * Specifies the URI used for API endpoint.
   *
   * @param apiBaseUri The base of our API endpoint
   * @return This
   */
  @NonNull
  public VietMapOptions apiBaseUri(String apiBaseUri) {
    this.apiBaseUri = apiBaseUri;
    return this;
  }

  /**
   * Specifies a the initial camera position for the map view.
   *
   * @param cameraPosition Inital camera position
   * @return This
   */
  @NonNull
  public VietMapOptions camera(CameraPosition cameraPosition) {
    this.cameraPosition = cameraPosition;
    return this;
  }

  /**
   * Specifies the used debug type for a map view.
   *
   * @param enabled True is debug is enabled
   * @return This
   */
  @NonNull
  public VietMapOptions debugActive(boolean enabled) {
    debugActive = enabled;
    return this;
  }

  /**
   * Specifies the used minimum zoom level for a map view.
   *
   * @param minZoom Zoom level to be used
   * @return This
   */
  @NonNull
  public VietMapOptions minZoomPreference(double minZoom) {
    this.minZoom = minZoom;
    return this;
  }

  /**
   * Specifies the used maximum zoom level for a map view.
   *
   * @param maxZoom Zoom level to be used
   * @return This
   */
  @NonNull
  public VietMapOptions maxZoomPreference(double maxZoom) {
    this.maxZoom = maxZoom;
    return this;
  }


  /**
   * Specifies the used minimum pitch for a map view.
   *
   * @param minPitch Pitch to be used
   * @return This
   */
  @NonNull
  public VietMapOptions minPitchPreference(double minPitch) {
    this.minPitch = minPitch;
    return this;
  }

  /**
   * Specifies the used maximum pitch for a map view.
   *
   * @param maxPitch Pitch to be used
   * @return This
   */
  @NonNull
  public VietMapOptions maxPitchPreference(double maxPitch) {
    this.maxPitch = maxPitch;
    return this;
  }

  /**
   * Specifies the visibility state of a mapbox_compass_icon for a map view.
   *
   * @param enabled True and mapbox_compass_icon is shown
   * @return This
   */
  @NonNull
  public VietMapOptions compassEnabled(boolean enabled) {
    compassEnabled = enabled;
    return this;
  }

  /**
   * Specifies the gravity state of mapbox_compass_icon for a map view.
   *
   * @param gravity Android SDK Gravity.
   * @return This
   */
  @NonNull
  public VietMapOptions compassGravity(int gravity) {
    compassGravity = gravity;
    return this;
  }

  /**
   * Specifies the margin state of mapbox_compass_icon for a map view
   *
   * @param margins 4 long array for LTRB margins
   * @return This
   */
  @NonNull
  public VietMapOptions compassMargins(int[] margins) {
    compassMargins = margins;
    return this;
  }

  /**
   * Specifies if the mapbox_compass_icon fades to invisible when facing north.
   * <p>
   * By default this value is true.
   * </p>
   *
   * @param compassFadeWhenFacingNorth true is mapbox_compass_icon fades to invisble
   * @return This
   */
  @NonNull
  public VietMapOptions compassFadesWhenFacingNorth(boolean compassFadeWhenFacingNorth) {
    this.fadeCompassFacingNorth = compassFadeWhenFacingNorth;
    return this;
  }

  /**
   * Specifies the image of the CompassView.
   * <p>
   * By default this value is R.drawable.mapbox_compass_icon.
   * </p>
   *
   * @param compass the drawable to show as image compass
   * @return This
   */
  @NonNull
  public VietMapOptions compassImage(Drawable compass) {
    this.compassImage = compass;
    return this;
  }

  /**
   * Specifies the visibility state of a logo for a map view.
   *
   * @param enabled True and logo is shown
   * @return This
   */
  @NonNull
  public VietMapOptions logoEnabled(boolean enabled) {
    logoEnabled = false;
    return this;
  }

  /**
   * Specifies the gravity state of logo for a map view.
   *
   * @param gravity Android SDK Gravity.
   * @return This
   */
  @NonNull
  public VietMapOptions logoGravity(int gravity) {
    logoGravity = gravity;
    return this;
  }

  /**
   * Specifies the margin state of logo for a map view
   *
   * @param margins 4 long array for LTRB margins
   * @return This
   */
  @NonNull
  public VietMapOptions logoMargins(int[] margins) {
    logoMargins = margins;
    return this;
  }

  /**
   * Specifies the visibility state of a attribution for a map view.
   *
   * @param enabled True and attribution is shown
   * @return This
   */
  @NonNull
  public VietMapOptions attributionEnabled(boolean enabled) {
    attributionEnabled = enabled;
    return this;
  }

  /**
   * Specifies the gravity state of attribution for a map view.
   *
   * @param gravity Android SDK Gravity.
   * @return This
   */
  @NonNull
  public VietMapOptions attributionGravity(int gravity) {
    attributionGravity = gravity;
    return this;
  }

  /**
   * Specifies the margin state of attribution for a map view
   *
   * @param margins 4 long array for LTRB margins
   * @return This
   */
  @NonNull
  public VietMapOptions attributionMargins(int[] margins) {
    attributionMargins = margins;
    return this;
  }

  /**
   * Specifies the tint color of the attribution for a map view
   *
   * @param color integer resembling a color
   * @return This
   */
  @NonNull
  public VietMapOptions attributionTintColor(@ColorInt int color) {
    attributionTintColor = color;
    return this;
  }

  /**
   * Specifies if the rotate gesture is enabled for a map view.
   *
   * @param enabled True and gesture will be enabled
   * @return This
   */
  @NonNull
  public VietMapOptions rotateGesturesEnabled(boolean enabled) {
    rotateGesturesEnabled = enabled;
    return this;
  }

  /**
   * Specifies if the scroll gesture is enabled for a map view.
   *
   * @param enabled True and gesture will be enabled
   * @return This
   */
  @NonNull
  public VietMapOptions scrollGesturesEnabled(boolean enabled) {
    scrollGesturesEnabled = enabled;
    return this;
  }

  /**
   * Specifies if the horizontal scroll gesture is enabled for a map view.
   *
   * @param enabled True and gesture will be enabled
   * @return This
   */
  @NonNull
  public VietMapOptions horizontalScrollGesturesEnabled(boolean enabled) {
    horizontalScrollGesturesEnabled = enabled;
    return this;
  }

  /**
   * Specifies if the tilt gesture is enabled for a map view.
   *
   * @param enabled True and gesture will be enabled
   * @return This
   */
  @NonNull
  public VietMapOptions tiltGesturesEnabled(boolean enabled) {
    tiltGesturesEnabled = enabled;
    return this;
  }

  /**
   * Specifies if the zoom gesture is enabled for a map view.
   *
   * @param enabled True and gesture will be enabled
   * @return This
   */
  @NonNull
  public VietMapOptions zoomGesturesEnabled(boolean enabled) {
    zoomGesturesEnabled = enabled;
    return this;
  }

  /**
   * Specifies if the double tap gesture is enabled for a map view.
   *
   * @param enabled True and gesture will be enabled
   * @return This
   */
  @NonNull
  public VietMapOptions doubleTapGesturesEnabled(boolean enabled) {
    doubleTapGesturesEnabled = enabled;
    return this;
  }

  /**
   * Specifies whether the user may zoom the map by tapping twice, holding and moving the pointer up and down.
   *
   * @param enabled True and gesture will be enabled
   * @return This
   */
  @NonNull
  public VietMapOptions quickZoomGesturesEnabled(boolean enabled) {
    quickZoomGesturesEnabled = enabled;
    return this;
  }

  /**
   * Enable {@link android.view.TextureView} as rendered surface.
   * <p>
   * Since the 5.2.0 release we replaced our TextureView with an {@link android.opengl.GLSurfaceView}
   * implementation. Enabling this option will use the {@link android.view.TextureView} instead.
   * {@link android.view.TextureView} can be useful in situations where you need to animate, scale
   * or transform the view. This comes at a siginficant performance penalty and should not be considered
   * unless absolutely needed.
   * </p>
   *
   * @param textureMode True to enable texture mode
   * @return This
   */
  @NonNull
  public VietMapOptions textureMode(boolean textureMode) {
    this.textureMode = textureMode;
    return this;
  }

  @NonNull
  public VietMapOptions translucentTextureSurface(boolean translucentTextureSurface) {
    this.translucentTextureSurface = translucentTextureSurface;
    return this;
  }

  /**
   * Set the MapView foreground color that is used when the map surface is being created.
   *
   * @param loadColor the color to show during map creation
   * @return This
   */
  @NonNull
  public VietMapOptions foregroundLoadColor(@ColorInt int loadColor) {
    this.foregroundLoadColor = loadColor;
    return this;
  }

  /**
   * Enable tile pre-fetching. Loads tiles at a lower zoom-level to pre-render
   * a low resolution preview while more detailed tiles are loaded.
   * Enabled by default
   *
   * @param enable true to enable
   * @return This
   * @deprecated Use {@link #setPrefetchZoomDelta(int)} instead.
   */
  @Deprecated
  @NonNull
  public VietMapOptions setPrefetchesTiles(boolean enable) {
    this.prefetchesTiles = enable;
    return this;
  }

  /**
   * Set the tile pre-fetching zoom delta. Pre-fetching makes sure that a low-resolution
   * tile at the (current_zoom_level - delta) is rendered as soon as possible at the
   * expense of a little bandwidth.
   * Note: This operation will override the VietMapOptions#setPrefetchesTiles(boolean)
   * Setting zoom delta to 0 will disable pre-fetching.
   * Default zoom delta is 4.
   *
   * @param delta zoom delta
   * @return This
   */
  @NonNull
  public VietMapOptions setPrefetchZoomDelta(@IntRange(from = 0) int delta) {
    this.prefetchZoomDelta = delta;
    return this;
  }

  /**
   * Enable cross-source symbol collision detection, defaults to true.
   * <p>
   * If set to false, symbol layers will only run collision detection against
   * other symbol layers that are part of the same source.
   * </p>
   *
   * @param crossSourceCollisions true to enable, false to disable
   * @return This
   */
  @NonNull
  public VietMapOptions crossSourceCollisions(boolean crossSourceCollisions) {
    this.crossSourceCollisions = crossSourceCollisions;
    return this;
  }

  /**
   * Enable local ideograph font family, defaults to true.
   *
   * @param enabled true to enable, false to disable
   * @return This
   */
  @NonNull
  public VietMapOptions localIdeographFontFamilyEnabled(boolean enabled) {
    this.localIdeographFontFamilyEnabled = enabled;
    return this;
  }

  /**
   * Set the font family for generating glyphs locally for ideographs in the &#x27;CJK Unified Ideographs&#x27;
   * and &#x27;Hangul Syllables&#x27; ranges.
   * <p>
   * The font family argument is passed to {@link android.graphics.Typeface#create(String, int)}.
   * Default system fonts are defined in &#x27;/system/etc/fonts.xml&#x27;
   * Default font for local ideograph font family is {@link VietmapConstants#DEFAULT_FONT}.
   *
   * @param fontFamily font family for local ideograph generation.
   * @return This
   */
  @NonNull
  public VietMapOptions localIdeographFontFamily(String fontFamily) {
    this.localIdeographFontFamily = FontUtils.extractValidFont(fontFamily);
    return this;
  }

  /**
   * Set a font family from range of font families for generating glyphs locally for ideographs in the
   * &#x27;CJK Unified Ideographs&#x27; and &#x27;Hangul Syllables&#x27; ranges. The first matching font
   * will be selected. If no valid font found, it defaults to {@link VietmapConstants#DEFAULT_FONT}.
   * <p>
   * The font families are checked against the default system fonts defined in
   * &#x27;/system/etc/fonts.xml&#x27; Default font for local ideograph font family is
   * {@link VietmapConstants#DEFAULT_FONT}.
   * </p>
   *
   * @param fontFamilies an array of font families for local ideograph generation.
   * @return This
   */
  @NonNull
  public VietMapOptions localIdeographFontFamily(String... fontFamilies) {
    this.localIdeographFontFamily = FontUtils.extractValidFont(fontFamilies);
    return this;
  }

  /**
   * Set the custom pixel ratio configuration to override the default value from resources.
   * This ratio will be used to initialise the map with.
   *
   * @param pixelRatio the custom pixel ratio of the map under construction
   * @return This
   */
  @NonNull
  public VietMapOptions pixelRatio(float pixelRatio) {
    this.pixelRatio = pixelRatio;
    return this;
  }

  /**
   * Check whether tile pre-fetching is enabled.
   *
   * @return true if enabled
   * @deprecated Use {@link #getPrefetchZoomDelta()} instead.
   */
  @Deprecated
  public boolean getPrefetchesTiles() {
    return prefetchesTiles;
  }

  /**
   * Check current pre-fetching zoom delta.
   *
   * @return current zoom delta.
   */
  @IntRange(from = 0)
  public int getPrefetchZoomDelta() {
    return prefetchZoomDelta;
  }

  /**
   * Check whether cross-source symbol collision detection is enabled.
   *
   * @return true if enabled
   */
  public boolean getCrossSourceCollisions() {
    return crossSourceCollisions;
  }

  /**
   * Set the flag to render the map surface on top of another surface.
   *
   * @param renderOnTop true if this map is shown on top of another one, false if bottom.
   */
  public void renderSurfaceOnTop(boolean renderOnTop) {
    this.zMediaOverlay = renderOnTop;
  }

  /**
   * Get the flag to render the map surface on top of another surface.
   *
   * @return true if this map is
   */
  public boolean getRenderSurfaceOnTop() {
    return zMediaOverlay;
  }

  /**
   * Get the current configured API endpoint base URL.
   *
   * @return Base URL to be used API endpoint.
   * @deprecated use {@link #getApiBaseUri()} instead
   */
  @Deprecated
  public String getApiBaseUrl() {
    return apiBaseUri;
  }

  /**
   * Get the current configured API endpoint base URI.
   *
   * @return Base URI to be used API endpoint.
   */
  public String getApiBaseUri() {
    return apiBaseUri;
  }

  /**
   * Get the current configured initial camera position for a map view.
   *
   * @return CameraPosition to be initially used.
   */
  public CameraPosition getCamera() {
    return cameraPosition;
  }

  /**
   * Get the current configured min zoom for a map view.
   *
   * @return Mininum zoom level to be used.
   */
  public double getMinZoomPreference() {
    return minZoom;
  }

  /**
   * Get the current configured maximum zoom for a map view.
   *
   * @return Maximum zoom to be used.
   */
  public double getMaxZoomPreference() {
    return maxZoom;
  }

  /**
   * Get the current configured min pitch for a map view.
   *
   * @return Mininum pitch to be used.
   */
  public double getMinPitchPreference() {
    return minPitch;
  }

  /**
   * Get the current configured maximum pitch for a map view.
   *
   * @return Maximum pitch to be used.
   */
  public double getMaxPitchPreference() {
    return maxPitch;
  }

  /**
   * Get the current configured visibility state for mapbox_compass_icon for a map view.
   *
   * @return Visibility state of the mapbox_compass_icon
   */
  public boolean getCompassEnabled() {
    return compassEnabled;
  }

  /**
   * Get the current configured gravity state for mapbox_compass_icon for a map view.
   *
   * @return Gravity state of the mapbox_compass_icon
   */
  public int getCompassGravity() {
    return compassGravity;
  }

  /**
   * Get the current configured margins for mapbox_compass_icon for a map view.
   *
   * @return Margins state of the mapbox_compass_icon
   */
  public int[] getCompassMargins() {
    return compassMargins;
  }

  /**
   * Get the current configured state for fading the mapbox_compass_icon when facing north.
   *
   * @return True if mapbox_compass_icon fades to invisible when facing north
   */
  public boolean getCompassFadeFacingNorth() {
    return fadeCompassFacingNorth;
  }

  /**
   * Get the current configured CompassView image.
   *
   * @return the drawable used as compass image
   */
  public Drawable getCompassImage() {
    return compassImage;
  }

  /**
   * Get the current configured visibility state for mapbox_compass_icon for a map view.
   *
   * @return Visibility state of the mapbox_compass_icon
   */
  public boolean getLogoEnabled() {
    return logoEnabled;
  }

  /**
   * Get the current configured gravity state for logo for a map view.
   *
   * @return Gravity state of the logo
   */
  public int getLogoGravity() {
    return logoGravity;
  }

  /**
   * Get the current configured margins for logo for a map view.
   *
   * @return Margins state of the logo
   */
  public int[] getLogoMargins() {
    return logoMargins;
  }

  /**
   * Get the current configured rotate gesture state for a map view.
   *
   * @return True indicates gesture is enabled
   */
  public boolean getRotateGesturesEnabled() {
    return rotateGesturesEnabled;
  }

  /**
   * Get the current configured scroll gesture state for a map view.
   *
   * @return True indicates gesture is enabled
   */
  public boolean getScrollGesturesEnabled() {
    return scrollGesturesEnabled;
  }

  /**
   * Get the current configured horizontal scroll gesture state for a map view.
   *
   * @return True indicates horizontal scroll gesture is enabled
   */
  public boolean getHorizontalScrollGesturesEnabled() {
    return horizontalScrollGesturesEnabled;
  }

  /**
   * Get the current configured tilt gesture state for a map view.
   *
   * @return True indicates gesture is enabled
   */
  public boolean getTiltGesturesEnabled() {
    return tiltGesturesEnabled;
  }

  /**
   * Get the current configured zoom gesture state for a map view.
   *
   * @return True indicates gesture is enabled
   */
  public boolean getZoomGesturesEnabled() {
    return zoomGesturesEnabled;
  }

  /**
   * Get the current configured double tap gesture state for a map view.
   *
   * @return True indicates gesture is enabled
   */
  public boolean getDoubleTapGesturesEnabled() {
    return doubleTapGesturesEnabled;
  }

  /**
   * Get whether the user may zoom the map by tapping twice, holding and moving the pointer up and down.
   *
   * @return True indicates gesture is enabled
   */
  public boolean getQuickZoomGesturesEnabled() {
    return quickZoomGesturesEnabled;
  }

  /**
   * Get the current configured visibility state for attribution for a map view.
   *
   * @return Visibility state of the attribution
   */
  public boolean getAttributionEnabled() {
    return attributionEnabled;
  }

  /**
   * Get the current configured gravity state for attribution for a map view.
   *
   * @return Gravity state of the logo
   */
  public int getAttributionGravity() {
    return attributionGravity;
  }

  /**
   * Get the current configured margins for attribution for a map view.
   *
   * @return Margins state of the logo
   */
  public int[] getAttributionMargins() {
    return attributionMargins;
  }

  /**
   * Get the current configured tint color for attribution for a map view.
   *
   * @return the tint color
   */
  @ColorInt
  public int getAttributionTintColor() {
    return attributionTintColor;
  }

  /**
   * Get the current configured debug state for a map view.
   *
   * @return True indicates debug is enabled.
   */
  public boolean getDebugActive() {
    return debugActive;
  }

  /**
   * Returns true if TextureView is being used the render view.
   *
   * @return True if TextureView is used.
   */
  public boolean getTextureMode() {
    return textureMode;
  }

  /**
   * Returns true if TextureView supports a translucent surface
   *
   * @return True if translucent surface is active
   */
  public boolean getTranslucentTextureSurface() {
    return translucentTextureSurface;
  }

  /**
   * Returns the current configured foreground color that is used during map creation.
   *
   * @return the load color
   */
  @ColorInt
  public int getForegroundLoadColor() {
    return foregroundLoadColor;
  }

  /**
   * Returns the font-family for locally overriding generation of glyphs in the
   * &#x27;CJK Unified Ideographs&#x27; and &#x27;Hangul Syllables&#x27; ranges.
   * Default font for local ideograph font family is {@link VietmapConstants#DEFAULT_FONT}.
   * Returns null if local ideograph font families are disabled.
   *
   * @return Local ideograph font family name.
   */
  @Nullable
  public String getLocalIdeographFontFamily() {
    return localIdeographFontFamilyEnabled ? localIdeographFontFamily : null;
  }

  /**
   * Returns true if local ideograph font family is enabled, defaults to true.
   *
   * @return True if local ideograph font family is enabled
   */
  public boolean isLocalIdeographFontFamilyEnabled() {
    return localIdeographFontFamilyEnabled;
  }

  /**
   * Return the custom configured pixel ratio, returns 0 if not configured.
   *
   * @return the pixel ratio used by the map under construction
   */
  public float getPixelRatio() {
    return pixelRatio;
  }

  public static final Parcelable.Creator<VietMapOptions> CREATOR = new Parcelable.Creator<VietMapOptions>() {
    public VietMapOptions createFromParcel(@NonNull Parcel in) {
      return new VietMapOptions(in);
    }

    public VietMapOptions[] newArray(int size) {
      return new VietMapOptions[size];
    }
  };

  @Override
  public int describeContents() {
    return 0;
  }

  @Override
  public void writeToParcel(@NonNull Parcel dest, int flags) {
    dest.writeParcelable(cameraPosition, flags);
    dest.writeByte((byte) (debugActive ? 1 : 0));

    dest.writeByte((byte) (compassEnabled ? 1 : 0));
    dest.writeInt(compassGravity);
    dest.writeIntArray(compassMargins);
    dest.writeByte((byte) (fadeCompassFacingNorth ? 1 : 0));
    dest.writeParcelable(compassImage != null
      ? BitmapUtils.getBitmapFromDrawable(compassImage) : null, flags);

    dest.writeByte((byte) (logoEnabled ? 1 : 0));
    dest.writeInt(logoGravity);
    dest.writeIntArray(logoMargins);

    dest.writeByte((byte) (attributionEnabled ? 1 : 0));
    dest.writeInt(attributionGravity);
    dest.writeIntArray(attributionMargins);
    dest.writeInt(attributionTintColor);

    dest.writeDouble(minZoom);
    dest.writeDouble(maxZoom);
    dest.writeDouble(minPitch);
    dest.writeDouble(maxPitch);

    dest.writeByte((byte) (rotateGesturesEnabled ? 1 : 0));
    dest.writeByte((byte) (scrollGesturesEnabled ? 1 : 0));
    dest.writeByte((byte) (horizontalScrollGesturesEnabled ? 1 : 0));
    dest.writeByte((byte) (tiltGesturesEnabled ? 1 : 0));
    dest.writeByte((byte) (zoomGesturesEnabled ? 1 : 0));
    dest.writeByte((byte) (doubleTapGesturesEnabled ? 1 : 0));
    dest.writeByte((byte) (quickZoomGesturesEnabled ? 1 : 0));

    dest.writeString(apiBaseUri);
    dest.writeByte((byte) (textureMode ? 1 : 0));
    dest.writeByte((byte) (translucentTextureSurface ? 1 : 0));
    dest.writeByte((byte) (prefetchesTiles ? 1 : 0));
    dest.writeInt(prefetchZoomDelta);
    dest.writeByte((byte) (zMediaOverlay ? 1 : 0));
    dest.writeByte((byte) (localIdeographFontFamilyEnabled ? 1 : 0));
    dest.writeString(localIdeographFontFamily);
    dest.writeStringArray(localIdeographFontFamilies);
    dest.writeFloat(pixelRatio);
    dest.writeInt(foregroundLoadColor);
    dest.writeByte((byte) (crossSourceCollisions ? 1 : 0));
  }

  @Override
  public boolean equals(@Nullable Object o) {
    if (this == o) {
      return true;
    }
    if (o == null || getClass() != o.getClass()) {
      return false;
    }

    VietMapOptions options = (VietMapOptions) o;

    if (debugActive != options.debugActive) {
      return false;
    }
    if (compassEnabled != options.compassEnabled) {
      return false;
    }
    if (fadeCompassFacingNorth != options.fadeCompassFacingNorth) {
      return false;
    }
    if (compassImage != null
      ? !compassImage.equals(options.compassImage)
      : options.compassImage != null) {
      return false;
    }
    if (compassGravity != options.compassGravity) {
      return false;
    }
    if (logoEnabled != options.logoEnabled) {
      return false;
    }
    if (logoGravity != options.logoGravity) {
      return false;
    }
    if (attributionTintColor != options.attributionTintColor) {
      return false;
    }
    if (attributionEnabled != options.attributionEnabled) {
      return false;
    }
    if (attributionGravity != options.attributionGravity) {
      return false;
    }
    if (Double.compare(options.minZoom, minZoom) != 0) {
      return false;
    }
    if (Double.compare(options.maxZoom, maxZoom) != 0) {
      return false;
    }
    if (Double.compare(options.minPitch, minPitch) != 0) {
      return false;
    }
    if (Double.compare(options.maxPitch, maxPitch) != 0) {
      return false;
    }
    if (rotateGesturesEnabled != options.rotateGesturesEnabled) {
      return false;
    }
    if (scrollGesturesEnabled != options.scrollGesturesEnabled) {
      return false;
    }
    if (horizontalScrollGesturesEnabled != options.horizontalScrollGesturesEnabled) {
      return false;
    }
    if (tiltGesturesEnabled != options.tiltGesturesEnabled) {
      return false;
    }
    if (zoomGesturesEnabled != options.zoomGesturesEnabled) {
      return false;
    }
    if (doubleTapGesturesEnabled != options.doubleTapGesturesEnabled) {
      return false;
    }
    if (quickZoomGesturesEnabled != options.quickZoomGesturesEnabled) {
      return false;
    }
    if (cameraPosition != null ? !cameraPosition.equals(options.cameraPosition) : options.cameraPosition != null) {
      return false;
    }
    if (!Arrays.equals(compassMargins, options.compassMargins)) {
      return false;
    }
    if (!Arrays.equals(logoMargins, options.logoMargins)) {
      return false;
    }
    if (!Arrays.equals(attributionMargins, options.attributionMargins)) {
      return false;
    }
    if (apiBaseUri != null ? !apiBaseUri.equals(options.apiBaseUri) : options.apiBaseUri != null) {
      return false;
    }
    if (prefetchesTiles != options.prefetchesTiles) {
      return false;
    }
    if (prefetchZoomDelta != options.prefetchZoomDelta) {
      return false;
    }
    if (zMediaOverlay != options.zMediaOverlay) {
      return false;
    }
    if (localIdeographFontFamilyEnabled != options.localIdeographFontFamilyEnabled) {
      return false;
    }
    if (!localIdeographFontFamily.equals(options.localIdeographFontFamily)) {
      return false;
    }
    if (!Arrays.equals(localIdeographFontFamilies, options.localIdeographFontFamilies)) {
      return false;
    }

    if (pixelRatio != options.pixelRatio) {
      return false;
    }

    if (crossSourceCollisions != options.crossSourceCollisions) {
      return false;
    }

    return false;
  }

  @Override
  public int hashCode() {
    int result;
    long temp;
    result = cameraPosition != null ? cameraPosition.hashCode() : 0;
    result = 31 * result + (debugActive ? 1 : 0);
    result = 31 * result + (compassEnabled ? 1 : 0);
    result = 31 * result + (fadeCompassFacingNorth ? 1 : 0);
    result = 31 * result + compassGravity;
    result = 31 * result + (compassImage != null ? compassImage.hashCode() : 0);
    result = 31 * result + Arrays.hashCode(compassMargins);
    result = 31 * result + (logoEnabled ? 1 : 0);
    result = 31 * result + logoGravity;
    result = 31 * result + Arrays.hashCode(logoMargins);
    result = 31 * result + attributionTintColor;
    result = 31 * result + (attributionEnabled ? 1 : 0);
    result = 31 * result + attributionGravity;
    result = 31 * result + Arrays.hashCode(attributionMargins);
    temp = Double.doubleToLongBits(minZoom);
    result = 31 * result + (int) (temp ^ (temp >>> 32));
    temp = Double.doubleToLongBits(maxZoom);
    result = 31 * result + (int) (temp ^ (temp >>> 32));
    temp = Double.doubleToLongBits(minPitch);
    result = 31 * result + (int) (temp ^ (temp >>> 32));
    temp = Double.doubleToLongBits(maxPitch);
    result = 31 * result + (int) (temp ^ (temp >>> 32));
    result = 31 * result + (rotateGesturesEnabled ? 1 : 0);
    result = 31 * result + (scrollGesturesEnabled ? 1 : 0);
    result = 31 * result + (horizontalScrollGesturesEnabled ? 1 : 0);
    result = 31 * result + (tiltGesturesEnabled ? 1 : 0);
    result = 31 * result + (zoomGesturesEnabled ? 1 : 0);
    result = 31 * result + (doubleTapGesturesEnabled ? 1 : 0);
    result = 31 * result + (quickZoomGesturesEnabled ? 1 : 0);
    result = 31 * result + (apiBaseUri != null ? apiBaseUri.hashCode() : 0);
    result = 31 * result + (textureMode ? 1 : 0);
    result = 31 * result + (translucentTextureSurface ? 1 : 0);
    result = 31 * result + (prefetchesTiles ? 1 : 0);
    result = 31 * result + prefetchZoomDelta;
    result = 31 * result + (zMediaOverlay ? 1 : 0);
    result = 31 * result + (localIdeographFontFamilyEnabled ? 1 : 0);
    result = 31 * result + (localIdeographFontFamily != null ? localIdeographFontFamily.hashCode() : 0);
    result = 31 * result + Arrays.hashCode(localIdeographFontFamilies);
    result = 31 * result + (int) pixelRatio;
    result = 31 * result + (crossSourceCollisions ? 1 : 0);
    return result;
  }
}
