package vn.vietmap.vietmapsdk.integration

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import androidx.test.rule.ActivityTestRule
import androidx.test.uiautomator.UiSelector
import com.mapbox.vietmapsdk.testapp.activity.fragment.ViewPagerActivity
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Regression test that validates MapFragment integration with a ViewPager
 */
@RunWith(AndroidJUnit4::class)
class ViewPagerScrollTest : BaseIntegrationTest() {

    @get:Rule
    var activityRule: ActivityTestRule<ViewPagerActivity> = ActivityTestRule(ViewPagerActivity::class.java)

    @Test
    @LargeTest
    fun scrollViewPager() {
        for (i in 1..4) {
            clickTab(i)
        }

        for (i in 3 downTo 0) {
            clickTab(i)
        }
    }

    private fun clickTab(index: Int) {
        device.findObject(UiSelector().text("Page $index")).click()
    }
}
