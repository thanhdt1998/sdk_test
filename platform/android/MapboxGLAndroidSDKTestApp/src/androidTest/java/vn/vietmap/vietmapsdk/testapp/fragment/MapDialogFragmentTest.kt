package vn.vietmap.vietmapsdk.testapp.fragment

import androidx.test.espresso.Espresso
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.matcher.ViewMatchers.withId
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import androidx.test.rule.ActivityTestRule
import com.mapbox.vietmapsdk.AppCenter
import vn.vietmap.vietmapsdk.testapp.R
import com.mapbox.vietmapsdk.testapp.activity.maplayout.MapInDialogActivity
import org.junit.Ignore
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Regression test that validates that a map inside a DialogFragment can be opened and closed.
 */
@RunWith(AndroidJUnit4::class)
@LargeTest
class MapDialogFragmentTest : AppCenter() {

    @get:Rule
    var activityRule: ActivityTestRule<MapInDialogActivity> = ActivityTestRule(MapInDialogActivity::class.java)

    @Test
    @Ignore
    fun openCloseDialog() {
        onView(withId(R.id.button_open_dialog)).perform(click())
        Thread.sleep(2500)
        Espresso.pressBack()
    }
}
