package vn.vietmap.vietmapsdk.testapp.activity.maplayout

import android.annotation.SuppressLint
import vn.vietmap.vietmapsdk.testapp.R

/**
 * TestActivity showcasing how to integrate multiple TexureView MapViews in a RecyclerView.
 */
@SuppressLint("ClickableViewAccessibility")
class TextureRecyclerViewActivity : GLSurfaceRecyclerViewActivity() {

    override fun getMapItemLayoutId(): Int {
        return R.layout.item_map_texture
    }
}
