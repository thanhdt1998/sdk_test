package vn.vietmap.vietmapsdk.style.expressions;

import android.graphics.Color;

import com.mapbox.geojson.Point;
import com.mapbox.geojson.Polygon;
import vn.vietmap.vietmapsdk.style.layers.PropertyValue;
import vn.vietmap.vietmapsdk.utils.ColorUtils;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import static vn.vietmap.vietmapsdk.style.expressions.Expression.FormatOption.formatFontScale;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.FormatOption.formatTextColor;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.FormatOption.formatTextFont;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.abs;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.acos;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.all;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.any;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.array;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.asin;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.at;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.atan;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.bool;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.ceil;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.coalesce;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.collator;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.color;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.concat;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.cos;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.cubicBezier;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.distance;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.division;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.downcase;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.e;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.eq;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.exponential;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.floor;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.format;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.formatEntry;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.geometryType;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.get;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.gt;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.gte;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.has;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.heatmapDensity;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.id;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.in;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.interpolate;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.isSupportedScript;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.length;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.let;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.linear;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.literal;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.ln;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.ln2;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.log10;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.log2;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.lt;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.lte;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.match;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.max;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.min;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.mod;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.neq;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.not;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.number;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.object;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.pi;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.pow;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.product;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.properties;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.raw;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.resolvedLocale;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.rgb;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.rgba;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.round;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.sin;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.sqrt;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.step;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.stop;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.string;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.subtract;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.sum;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.switchCase;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.tan;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.toBool;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.toColor;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.toNumber;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.toRgba;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.typeOf;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.upcase;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.var;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.within;
import static vn.vietmap.vietmapsdk.style.expressions.Expression.zoom;
import static vn.vietmap.vietmapsdk.style.layers.PropertyFactory.lineOpacity;
import static vn.vietmap.vietmapsdk.style.layers.PropertyFactory.lineWidth;
import static junit.framework.Assert.assertTrue;
import static org.junit.Assert.assertEquals;

/**
 * Expression unit tests that validate the expression output with the expected Object[]array representation.
 */
@RunWith(RobolectricTestRunner.class)
public class ExpressionTest {

  @Test
  public void testPropertyValueIsExpression() {
    PropertyValue<?> property = lineWidth(Expression.get("width"));
    assertTrue(property.isExpression());
  }

  @Test
  public void testPropertyValueEqualsExpression() {
    PropertyValue<?> property = lineWidth(Expression.get("width"));
    assertEquals(Expression.get("width"), property.getExpression());
  }

  @Test
  public void testRgb() throws Exception {
    Object[] expected = new Object[] {"rgb", 0f, 0f, 0f};
    Object[] actual = rgb(literal(0), literal(0), literal(0)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testRgbLiteral() throws Exception {
    Object[] expected = new Object[] {"rgb", 0f, 0f, 0f};
    Object[] actual = rgb(0, 0, 0).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testRgba() throws Exception {
    Object[] expected = new Object[] {"rgba", 0f, 0f, 0f, 1f};
    Object[] actual = rgba(literal(0), literal(0), literal(0), literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testRgbaLiteral() throws Exception {
    Object[] expected = new Object[] {"rgba", 0f, 0f, 0f, 1f};
    Object[] actual = rgba(0, 0, 0, 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testToRgba() throws Exception {
    Object[] expected = new Object[] {"to-rgba", new Object[] {"to-color", "rgba(255, 0, 0, 1)"}};
    Object[] actual = toRgba(toColor(literal(ColorUtils.colorToRgbaString(Color.RED)))).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testEq() throws Exception {
    Object[] expected = new Object[] {"==", 1f, 1f};
    Object[] actual = eq(literal(1), literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testEqLiteral() throws Exception {
    Object[] expected = new Object[] {"==", 1f, 1f};
    Object[] actual = eq(literal(1), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testEqExpression() throws Exception {
    Object[] expected = new Object[] {"==", new Object[] {"get", "hello"}, 1f};
    Object[] actual = eq(get("hello"), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testNeq() throws Exception {
    Object[] expected = new Object[] {"!=", 0f, 1f};
    Object[] actual = neq(literal(0), literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testNeqLiteral() throws Exception {
    Object[] expected = new Object[] {"!=", 0f, 1f};
    Object[] actual = neq(literal(0), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testNeqExpression() throws Exception {
    Object[] expected = new Object[] {"!=", new Object[] {"get", "hello"}, 1f};
    Object[] actual = neq(get("hello"), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGt() throws Exception {
    Object[] expected = new Object[] {">", 0f, 1f};
    Object[] actual = gt(literal(0), literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGtLiteral() throws Exception {
    Object[] expected = new Object[] {">", 0f, 1f};
    Object[] actual = gt(literal(0), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGtExpression() throws Exception {
    Object[] expected = new Object[] {">", new Object[] {"get", "hello"}, 1f};
    Object[] actual = gt(get("hello"), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLt() throws Exception {
    Object[] expected = new Object[] {"<", 1f, 0f};
    Object[] actual = lt(literal(1), literal(0)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLtLiteral() throws Exception {
    Object[] expected = new Object[] {"<", 1f, 0f};
    Object[] actual = lt(literal(1), 0).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLtExpression() throws Exception {
    Object[] expected = new Object[] {"<", new Object[] {"get", "hello"}, 1f};
    Object[] actual = lt(get("hello"), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGte() throws Exception {
    Object[] expected = new Object[] {">=", 1f, 1f};
    Object[] actual = gte(literal(1), literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGteLiteral() throws Exception {
    Object[] expected = new Object[] {">=", 1f, 1f};
    Object[] actual = gte(literal(1), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGteExpression() throws Exception {
    Object[] expected = new Object[] {">=", new Object[] {"get", "hello"}, 1f};
    Object[] actual = gte(get("hello"), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLte() throws Exception {
    Object[] expected = new Object[] {"<=", 1f, 1f};
    Object[] actual = lte(literal(1), literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLteExpression() throws Exception {
    Object[] expected = new Object[] {"<=", new Object[] {"get", "hello"}, 1f};
    Object[] actual = lte(get("hello"), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLteLiteral() throws Exception {
    Object[] expected = new Object[] {"<=", 1f, 1f};
    Object[] actual = lte(literal(1), 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAll() throws Exception {
    Object[] expected = new Object[] {"all", true, true, true};
    Object[] actual = all(literal(true), literal(true), literal(true)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAny() throws Exception {
    Object[] expected = new Object[] {"any", true, false, false};
    Object[] actual = any(literal(true), literal(false), literal(false)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testNot() throws Exception {
    Object[] expected = new Object[] {"!", false};
    Object[] actual = not(literal(false)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testNotLiteral() throws Exception {
    Object[] expected = new Object[] {"!", false};
    Object[] actual = not(false).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSwitchCase() throws Exception {
    Object[] expectedCaseOneGet = new Object[] {"get", "key1"};
    Object[] expectedCaseOne = new Object[] {"==", expectedCaseOneGet, "value1"};
    Object[] expectedCaseTwoGet = new Object[] {"get", "key2"};
    Object[] expectedCaseTwo = new Object[] {"!=", expectedCaseTwoGet, "value2"};
    Object[] expected = new Object[] {"case", expectedCaseOne, expectedCaseTwo};

    Object[] actual = switchCase(
      eq(get(literal("key1")), literal("value1")),
      neq(get(literal("key2")), literal("value2"))
    ).toArray();

    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSwitchCaseLiteral() throws Exception {
    Object[] expectedCaseOneGet = new Object[] {"get", "key1"};
    Object[] expectedCaseOne = new Object[] {"==", expectedCaseOneGet, "value1"};
    Object[] expectedCaseTwoGet = new Object[] {"get", "key2"};
    Object[] expectedCaseTwo = new Object[] {"!=", expectedCaseTwoGet, "value2"};
    Object[] expected = new Object[] {"case", expectedCaseOne, expectedCaseTwo};

    Object[] actual = switchCase(
      eq(get("key1"), literal("value1")),
      neq(get("key2"), literal("value2"))
    ).toArray();

    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testMatch() throws Exception {
    String input = "input";
    String[] labels = new String[] {"a", "b", "c"};
    String[] outputs = new String[] {"1", "2", "3"};
    String defaultOutput = "0";

    Object[] expected = new Object[] {"match", input,
      labels[0], outputs[0],
      labels[1], outputs[1],
      labels[2], outputs[2],
      defaultOutput};

    Object[] actual = match(literal(input),
      literal(labels[0]), literal(outputs[0]),
      literal(labels[1]), literal(outputs[1]),
      literal(labels[2]), literal(outputs[2]),
      literal(defaultOutput)
    ).toArray();

    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testMatchWithStops() throws Exception {
    String input = "input";
    String[] labels = new String[] {"a", "b", "c"};
    String[] outputs = new String[] {"1", "2", "3"};
    String defaultOutput = "0";

    Object[] expected = new Object[] {"match", input,
      labels[0], outputs[0],
      labels[1], outputs[1],
      labels[2], outputs[2],
      defaultOutput};

    Object[] actual = match(literal(input), literal(defaultOutput),
      stop(labels[0], outputs[0]),
      stop(labels[1], outputs[1]),
      stop(labels[2], outputs[2]))
      .toArray();

    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCoalesce() throws Exception {
    Object[] expectedGetOne = new Object[] {"get", "invalidKey"};
    Object[] expectedGetTwo = new Object[] {"get", "validKey"};
    Object[] expected = new Object[] {"coalesce", expectedGetOne, expectedGetTwo};

    Object[] actual = coalesce(
      get(literal("invalidKey")),
      get(literal("validKey"))
    ).toArray();

    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCoalesceLiteral() throws Exception {
    Object[] expectedGetOne = new Object[] {"get", "invalidKey"};
    Object[] expectedGetTwo = new Object[] {"get", "validKey"};
    Object[] expected = new Object[] {"coalesce", expectedGetOne, expectedGetTwo};

    Object[] actual = coalesce(
      get("invalidKey"),
      get("validKey")
    ).toArray();

    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testProperties() throws Exception {
    Object[] expected = new Object[] {"properties"};
    Object[] actual = properties().toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGeometryType() throws Exception {
    Object[] expected = new Object[] {"geometry-type"};
    Object[] actual = geometryType().toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testId() throws Exception {
    Object[] expected = new Object[] {"id"};
    Object[] actual = id().toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testHeatmapDensity() throws Exception {
    Object[] expected = new Object[] {"heatmap-density"};
    Object[] actual = heatmapDensity().toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAt() throws Exception {
    Object[] expected = new Object[] {"at", 3f, new Object[] {"literal", new Object[] {"one", "two"}}};
    Object[] actual = at(literal(3), literal(new Object[] {"one", "two"})).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testInString() throws Exception {
    Object[] expected = new Object[] {"in", "one", "onetwo"};
    Object[] actual = in(literal("one"), literal("onetwo")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testWithIn() throws Exception {
    List<List<Point>> lngLats = Collections.singletonList(
      Arrays.asList(
        Point.fromLngLat(0, 0),
        Point.fromLngLat(0, 5),
        Point.fromLngLat(5, 5),
        Point.fromLngLat(5, 0),
        Point.fromLngLat(0, 0)
      )
    );

    Polygon polygon = Polygon.fromLngLats(lngLats);
    HashMap<String, String> map = new HashMap<>();
    map.put("type", "Polygon");
    map.put("json", polygon.toJson());
    Object[] expected = new Object[] {"within", map};
    Object[] actual = within(polygon).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testInNumber() throws Exception {
    Object[] expected = new Object[] {"in", 1f, new Object[] {"literal", new Object[] {1f, 2f}}};
    Object[] actual = in(literal(1f), literal(new Object[] {1f, 2f})).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }


  @Test
  public void testDistance() throws Exception {
    Point point = Point.fromLngLat(1, 2);
    HashMap<String, String> map = new HashMap<>();
    map.put("json", point.toJson());
    Object[] expected = new Object[] {"distance", map};
    Object[] actual = distance(point).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }


  @Test
  public void testInArray() throws Exception {
    Object[] expected = new Object[] {"in", "one", new Object[] {"literal", new Object[] {"one", "two"}}};
    Object[] actual = in(literal("one"), literal(new Object[] {"one", "two"})).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAtLiteral() throws Exception {
    Object[] expected = new Object[] {"at", 3f, new Object[] {"literal", new Object[] {"one", "two"}}};
    Object[] actual = at(3, literal(new Object[] {"one", "two"})).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAtExpression() throws Exception {
    Object[] expected = new Object[] {"at", 3f, new Object[] {"properties"}};
    Object[] actual = at(literal(3), properties()).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGet() throws Exception {
    Object[] expected = new Object[] {"get", "key"};
    Object[] actual = get(literal("key")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGetLiteral() throws Exception {
    Object[] expected = new Object[] {"get", "key"};
    Object[] actual = get("key").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGetObject() throws Exception {
    Object[] expected = new Object[] {"get", "key", new Object[] {"properties"}};
    Object[] actual = get(literal("key"), properties()).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testGetObjectLiteral() throws Exception {
    Object[] expected = new Object[] {"get", "key", new Object[] {"properties"}};
    Object[] actual = get("key", properties()).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testHas() throws Exception {
    Object[] expected = new Object[] {"has", "key"};
    Object[] actual = has(literal("key")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testHasLiteral() throws Exception {
    Object[] expected = new Object[] {"has", "key"};
    Object[] actual = has("key").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testHasObject() throws Exception {
    Object[] expected = new Object[] {"has", "key", new Object[] {"properties"}};
    Object[] actual = has(literal("key"), properties()).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testHasObjectLiteral() throws Exception {
    Object[] expected = new Object[] {"has", "key", new Object[] {"properties"}};
    Object[] actual = has("key", properties()).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testHasExpression() throws Exception {
    Object[] expected = new Object[] {"has", new Object[] {"get", "key"}, new Object[] {"properties"}};
    Object[] actual = has(get(literal("key")), properties()).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testHasExpressionLiteral() throws Exception {
    Object[] expected = new Object[] {"has", new Object[] {"get", "key"}, new Object[] {"properties"}};
    Object[] actual = has(get("key"), properties()).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLength() throws Exception {
    Object[] expected = new Object[] {"length", "key"};
    Object[] actual = length(literal("key")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLengthLiteral() throws Exception {
    Object[] expected = new Object[] {"length", "key"};
    Object[] actual = length("key").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLengthExpression() throws Exception {
    Object[] expected = new Object[] {"length", new Object[] {"get", "key"}};
    Object[] actual = length(get(literal("key"))).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLn2() throws Exception {
    Object[] expected = new Object[] {"ln2"};
    Object[] actual = ln2().toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testPi() throws Exception {
    Object[] expected = new Object[] {"pi"};
    Object[] actual = pi().toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testE() throws Exception {
    Object[] expected = new Object[] {"e"};
    Object[] actual = e().toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSum() throws Exception {
    Object[] expected = new Object[] {"+", 1f, 2f};
    Object[] actual = sum(literal(1), literal(2)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSumLiteral() throws Exception {
    Object[] expected = new Object[] {"+", 1f, 2f};
    Object[] actual = sum(1, 2).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testProduct() throws Exception {
    Object[] expected = new Object[] {"*", 1f, 2f};
    Object[] actual = product(literal(1), literal(2)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testProductLiteral() throws Exception {
    Object[] expected = new Object[] {"*", 1f, 2f};
    Object[] actual = product(1, 2).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSubtract() throws Exception {
    Object[] expected = new Object[] {"-", 2f, 1f};
    Object[] actual = subtract(literal(2), literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSubtractLiteral() throws Exception {
    Object[] expected = new Object[] {"-", 2f, 1f};
    Object[] actual = subtract(2, 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testDivision() throws Exception {
    Object[] expected = new Object[] {"/", 2f, 1f};
    Object[] actual = division(literal(2), literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testDivisionLiteral() throws Exception {
    Object[] expected = new Object[] {"/", 2f, 1f};
    Object[] actual = division(2, 1).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testDivisionWithNestedGet() throws Exception {
    Object nestedGet = new Object[] {"get", "key"};
    Object[] expected = new Object[] {"/", 2f, nestedGet};
    Object[] actual = division(literal(2), get(literal("key"))).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testMod() throws Exception {
    Object[] expected = new Object[] {"%", 1f, 3f};
    Object[] actual = mod(literal(1), literal(3)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testModLiteral() throws Exception {
    Object[] expected = new Object[] {"%", 1f, 3f};
    Object[] actual = mod(1, 3).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testPow() throws Exception {
    Object[] expected = new Object[] {"^", 2f, 3f};
    Object[] actual = pow(literal(2), literal(3)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testPowLiteral() throws Exception {
    Object[] expected = new Object[] {"^", 2f, 3f};
    Object[] actual = pow(2, 3).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSqrt() throws Exception {
    Object[] expected = new Object[] {"sqrt", 4f};
    Object[] actual = sqrt(literal(4)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSqrtLiteral() throws Exception {
    Object[] expected = new Object[] {"sqrt", 4f};
    Object[] actual = sqrt(4).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLog10() throws Exception {
    Object[] expected = new Object[] {"log10", 10f};
    Object[] actual = log10(literal(10f)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLog10Literal() throws Exception {
    Object[] expected = new Object[] {"log10", 10f};
    Object[] actual = log10(10).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLn() throws Exception {
    Object[] expected = new Object[] {"ln", 2f};
    Object[] actual = ln(literal(2)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLnLiteral() throws Exception {
    Object[] expected = new Object[] {"ln", 2f};
    Object[] actual = ln(2).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLog2() throws Exception {
    Object[] expected = new Object[] {"log2", 16f};
    Object[] actual = log2(literal(16)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLog2Literal() throws Exception {
    Object[] expected = new Object[] {"log2", 16f};
    Object[] actual = log2(16).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSin() throws Exception {
    Object[] expected = new Object[] {"sin", 45f};
    Object[] actual = sin(literal(45)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testSinLiteral() throws Exception {
    Object[] expected = new Object[] {"sin", 45f};
    Object[] actual = sin(45).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCos() throws Exception {
    Object[] expected = new Object[] {"cos", 45f};
    Object[] actual = cos(literal(45)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCosLiteral() throws Exception {
    Object[] expected = new Object[] {"cos", 45f};
    Object[] actual = cos(45).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testTan() throws Exception {
    Object[] expected = new Object[] {"tan", 45f};
    Object[] actual = tan(literal(45)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testTanLiteral() throws Exception {
    Object[] expected = new Object[] {"tan", 45f};
    Object[] actual = tan(45).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAsin() throws Exception {
    Object[] expected = new Object[] {"asin", 45f};
    Object[] actual = asin(literal(45)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAsinLiteral() throws Exception {
    Object[] expected = new Object[] {"asin", 45f};
    Object[] actual = asin(45).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAcos() throws Exception {
    Object[] expected = new Object[] {"acos", 45f};
    Object[] actual = acos(literal(45)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAcosLiteral() throws Exception {
    Object[] expected = new Object[] {"acos", 45f};
    Object[] actual = acos(45).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAtan() throws Exception {
    Object[] expected = new Object[] {"atan", 45f};
    Object[] actual = atan(literal(45)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAtanLiteral() throws Exception {
    Object[] expected = new Object[] {"atan", 45f};
    Object[] actual = atan(45).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testMin() throws Exception {
    Object[] expected = new Object[] {"min", 0f, 1f, 2f, 3f};
    Object[] actual = min(literal(0), literal(1), literal(2), literal(3)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testMinLiteral() throws Exception {
    Object[] expected = new Object[] {"min", 0f, 1f, 2f, 3f};
    Object[] actual = min(0, 1, 2, 3).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testMax() throws Exception {
    Object[] expected = new Object[] {"max", 0f, 1f, 2f, 3f};
    Object[] actual = max(literal(0), literal(1), literal(2), literal(3)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testMaxLiteral() throws Exception {
    Object[] expected = new Object[] {"max", 0f, 1f, 2f, 3f};
    Object[] actual = max(0, 1, 2, 3).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testUpcase() throws Exception {
    Object[] expected = new Object[] {"upcase", "string"};
    Object[] actual = upcase(literal("string")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testUpcaseLiteral() throws Exception {
    Object[] expected = new Object[] {"upcase", "string"};
    Object[] actual = upcase("string").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testDowncase() throws Exception {
    Object[] expected = new Object[] {"downcase", "string"};
    Object[] actual = downcase(literal("string")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testDowncaseLiteral() throws Exception {
    Object[] expected = new Object[] {"downcase", "string"};
    Object[] actual = downcase("string").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testConcat() throws Exception {
    Object[] expected = new Object[] {"concat", "foo", "bar"};
    Object[] actual = concat(literal("foo"), literal("bar")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testConcatLiteral() throws Exception {
    Object[] expected = new Object[] {"concat", "foo", "bar"};
    Object[] actual = concat("foo", "bar").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testArray() throws Exception {
    Object[] get = new Object[] {"get", "keyToArray"};
    Object[] expected = new Object[] {"array", get};
    Object[] actual = array(get(literal("keyToArray"))).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testArrayLiteral() throws Exception {
    Object[] get = new Object[] {"get", "keyToArray"};
    Object[] expected = new Object[] {"array", get};
    Object[] actual = array(get("keyToArray")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testTypeOf() throws Exception {
    Object[] expected = new Object[] {"typeof", "value"};
    Object[] actual = typeOf(literal("value")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testString() throws Exception {
    Object[] expected = new Object[] {"string", "value"};
    Object[] actual = string(literal("value")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testNumber() throws Exception {
    Object[] expected = new Object[] {"number", 1f};
    Object[] actual = number(literal(1)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testBool() throws Exception {
    Object[] expected = new Object[] {"boolean", true};
    Object[] actual = bool(literal(true)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testObject() throws Exception {
    Object object = new Object();
    Object[] expected = new Object[] {"object", object};
    Object[] actual = object(literal(object)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testToString() throws Exception {
    Object[] expected = new Object[] {"to-string", 3f};
    Object[] actual = Expression.toString(literal(3)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testToNumber() throws Exception {
    Object[] expected = new Object[] {"to-number", "3"};
    Object[] actual = toNumber(literal("3")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testToBool() throws Exception {
    Object[] expected = new Object[] {"to-boolean", "true"};
    Object[] actual = toBool(literal("true")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testToColor() throws Exception {
    Object[] expected = new Object[] {"to-color", "value"};
    Object[] actual = toColor(literal("value")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLet() throws Exception {
    Object[] expected = new Object[] {"let", "letName", "value"};
    Object[] actual = let(literal("letName"), literal("value")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testVar() throws Exception {
    Object[] expected = new Object[] {"var", "letName"};
    Object[] actual = var(literal("letName")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testVarLiteral() throws Exception {
    Object[] expected = new Object[] {"var", "letName"};
    Object[] actual = var("letName").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testVarExpression() throws Exception {
    Object[] expected = new Object[] {"var", new Object[] {"get", "letName"}};
    Object[] actual = var(get(literal("letName"))).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testVarExpressionLiteral() throws Exception {
    Object[] expected = new Object[] {"var", new Object[] {"get", "letName"}};
    Object[] actual = var(get("letName")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testZoom() throws Exception {
    Object[] expected = new Object[] {"zoom"};
    Object[] actual = zoom().toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testStepBasic() throws Exception {
    Object[] expected = new Object[] {"step", 12f, 11f, 0f, 111f, 1f, 1111f};
    Object[] actual = step(literal(12), literal(11), literal(0), literal(111), literal(1), literal(1111)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testStepBasicLiteral() throws Exception {
    Object[] expected = new Object[] {"step", new Object[] {"get", "line-width"}, 11f, 0f, 111f, 1f, 1111f};
    Object[] actual = step(get("line-width"), literal(11), stop(0, 111), stop(1, 1111)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testStepExpression() throws Exception {
    Object[] input = new Object[] {"get", "key"};
    Object[] number = new Object[] {"to-number", input};
    Object[] expected = new Object[] {"step", number, 11f, 0f, 111f, 1f, 1111f};
    Object[] actual = step(toNumber(get(literal("key"))),
      literal(11), literal(0), literal(111), literal(1), literal(1111)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testStepExpressionLiteral() throws Exception {
    Object[] input = new Object[] {"get", "key"};
    Object[] number = new Object[] {"to-number", input};
    Object[] expected = new Object[] {"step", number, 11f, 0f, 111f, 1f, 1111f};
    Object[] actual = step(toNumber(get("key")), literal(11), stop(0, 111), stop(1, 1111)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLinear() throws Exception {
    Object[] expected = new Object[] {"interpolate", new Object[] {"linear"}, 12f, 0f, 1f, 1f, 2f, 2f, 3f};
    Object[] actual = interpolate(
      linear(), literal(12),
      literal(0), literal(1),
      literal(1), literal(2),
      literal(2), literal(3))
      .toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLinearStops() throws Exception {
    Object[] expected = new Object[] {"interpolate", new Object[] {"linear"}, 12f, 0f, 1f, 1f, 2f, 2f, 3f};
    Object[] actual = interpolate(linear(), literal(12), stop(0, 1), stop(1, 2), stop(2, 3)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testExponential() throws Exception {
    Object[] exponential = new Object[] {"exponential", 12f};
    Object[] get = new Object[] {"get", "x"};
    Object[] expected = new Object[] {"interpolate", exponential, get, 0f, 100f, 200f};
    Object[] actual = interpolate(exponential(literal(12)),
      get(literal("x")), literal(0), literal(100), literal(200)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testExponentialLiteral() throws Exception {
    Object[] exponential = new Object[] {"exponential", 12f};
    Object[] get = new Object[] {"get", "x"};
    Object[] expected = new Object[] {"interpolate", exponential, get, 0f, 100f, 100f, 200f};
    Object[] actual = interpolate(exponential(12), get("x"), stop(0, 100), stop(100, 200)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testExponentialExpressionLiteral() throws Exception {
    Object[] getX = new Object[] {"get", "x"};
    Object[] exponential = new Object[] {"exponential", getX};
    Object[] getY = new Object[] {"get", "y"};
    Object[] expected = new Object[] {"interpolate", exponential, getY, 0f, 100f, 100f, 200f};
    Object[] actual = interpolate(exponential(get("x")), get("y"), stop(0, 100), stop(100, 200)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCubicBezier() throws Exception {
    Object[] cubicBezier = new Object[] {"cubic-bezier", 1f, 1f, 1f, 1f};
    Object[] get = new Object[] {"get", "x"};
    Object[] expected = new Object[] {"interpolate", cubicBezier, get, 0f, 100f, 100f, 200f};
    Object[] actual = interpolate(cubicBezier(literal(1), literal(1), literal(1), literal(1)),
      get(literal("x")), literal(0), literal(100), literal(100), literal(200)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCubicBezierLiteral() throws Exception {
    Object[] cubicBezier = new Object[] {"cubic-bezier", 1f, 1f, 1f, 1f};
    Object[] get = new Object[] {"get", "x"};
    Object[] expected = new Object[] {"interpolate", cubicBezier, get, 0f, 100f, 100f, 200f};
    Object[] actual = interpolate(cubicBezier(1, 1, 1, 1), get("x"), stop(0, 100), stop(100, 200)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCubicBezierExpression() throws Exception {
    Object[] getX = new Object[] {"get", "x"};
    Object[] getY = new Object[] {"get", "y"};
    Object[] getZ = new Object[] {"get", "z"};
    Object[] cubicBezier = new Object[] {"cubic-bezier", getZ, 1f, getY, 1f};
    Object[] expected = new Object[] {"interpolate", cubicBezier, getX, 0f, 100f, 200f};
    Object[] actual = interpolate(cubicBezier(get(literal("z")), literal(1),
      get(literal("y")), literal(1)), get(literal("x")), literal(0), literal(100), literal(200)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCubicBezierExpressionLiteral() throws Exception {
    Object[] getX = new Object[] {"get", "x"};
    Object[] getY = new Object[] {"get", "y"};
    Object[] getZ = new Object[] {"get", "z"};
    Object[] cubicBezier = new Object[] {"cubic-bezier", getZ, 1f, getY, 1f};
    Object[] expected = new Object[] {"interpolate", cubicBezier, getX, 0f, 100f, 100f, 200f};
    Object[] actual = interpolate(cubicBezier(get("z"), literal(1), get("y"),
      literal(1)), get("x"), stop(0, 100), stop(100, 200)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testExpressionConcatToString() throws Exception {
    String expected = "[\"concat\", \"foo\", \"bar\"]";
    String actual = concat(literal("foo"), literal("bar")).toString();
    assertEquals("toString should match", expected, actual);
  }

  @Test
  public void testExpressionMinToString() throws Exception {
    String expected = "[\"min\", 0.0, 1.0, 2.0, 3.0]";
    String actual = min(0, 1, 2, 3).toString();
    assertEquals("toString should match", expected, actual);
  }

  @Test
  public void testExpressionExponentialToString() throws Exception {
    String expected = "[\"interpolate\", [\"cubic-bezier\", 1.0, 1.0, 1.0, 1.0],"
      + " [\"get\", \"x\"], 0.0, 100.0, 100.0, 200.0]";
    String actual = interpolate(cubicBezier(literal(1), literal(1), literal(1), literal(1)),
      get(literal("x")), literal(0), literal(100), literal(100), literal(200)).toString();
    assertEquals("toString should match", expected, actual);
  }

  @Test
  public void testLiteralArray() throws Exception {
    Object[] array = new Object[] {1, "text"};
    Object[] expected = new Object[] {"literal", array};
    Object[] actual = literal(array).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testLiteralArrayString() throws Exception {
    Object[] array = new Object[] {1, "text"};
    String expected = "[\"literal\", [1, \"text\"]]";
    String actual = literal(array).toString();
    assertEquals("literal array should match", expected, actual);
  }

  @Test
  public void testLiteralPrimitiveArrayConversion() throws Exception {
    float[] array = new float[] {0.2f, 0.5f};
    Object[] expected = new Object[] {"literal", new Object[] {0.2f, 0.5f}};
    Object[] actual = literal(array).toArray();
    assertEquals("primitive array should be converted", expected, actual);
  }

  @Test
  public void testColorConversion() {
    Expression greenColor = color(0xFF00FF00);
    Object[] expected = new Object[] {"rgba", 0f, 255f, 0f, 1f};
    assertTrue("expression should match", Arrays.deepEquals(expected, greenColor.toArray()));
  }

  @Test(expected = IllegalArgumentException.class)
  public void testThrowIllegalArgumentExceptionForPropertyValueLiteral() {
    Expression expression = interpolate(exponential(1f), zoom(),
      stop(17f, lineOpacity(1f)),
      stop(16.5f, lineOpacity(0.5f)),
      stop(16f, lineOpacity(0f))
    );
    expression.toArray();
  }

  @Test
  public void testRound() {
    Object[] expected = new Object[] {"round", 2.2f};
    Object[] actual = round(2.2f).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testRoundLiteral() {
    Object[] expected = new Object[] {"round", 2.2f};
    Object[] actual = round(literal(2.2f)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAbs() {
    Object[] expected = new Object[] {"abs", -2.2f};
    Object[] actual = abs(-2.2f).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testAbsLiteral() {
    Object[] expected = new Object[] {"abs", -2.2f};
    Object[] actual = abs(literal(-2.2f)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCeil() {
    Object[] expected = new Object[] {"ceil", 2.2f};
    Object[] actual = ceil(2.2f).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testCeilLiteral() {
    Object[] expected = new Object[] {"ceil", 2.2f};
    Object[] actual = ceil(literal(2.2f)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testFloor() {
    Object[] expected = new Object[] {"floor", 2.2f};
    Object[] actual = floor(2.2f).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testFloorLiteral() {
    Object[] expected = new Object[] {"floor", 2.2f};
    Object[] actual = floor(literal(2.2f)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testRawEmpty() {
    String raw = "[\"get\", ]";
    Expression expected = get("");
    assertEquals("expressions should match", raw(raw), expected);

    raw = "[\"get\", key]";
    expected = get("key");
    assertEquals("expressions should match", raw(raw), expected);
  }

  @Test
  public void testRawAndroidColors() {
    Expression expected = interpolate(linear(), zoom(),
      stop(12, step(get("stroke-width"),
        color(Color.BLACK),
        stop(1f, color(Color.RED)),
        stop(2f, color(Color.WHITE)),
        stop(3f, color(Color.BLUE))
      )),
      stop(15, step(get("stroke-width"),
        color(Color.BLACK),
        stop(1f, color(Color.YELLOW)),
        stop(2f, color(Color.LTGRAY)),
        stop(3f, color(Color.CYAN))
      )),
      stop(18, step(get("stroke-width"),
        color(Color.BLACK),
        stop(1f, color(Color.WHITE)),
        stop(2f, color(Color.GRAY)),
        stop(3f, color(Color.GREEN))
      ))
    );
    assertEquals("expressions should match", expected, raw(expected.toString()));
  }

  @Test
  public void testRawRgbaColor() {
    Expression expected = interpolate(
      exponential(2f), zoom(),
      literal(5f), literal("rgba(0, 0, 0, 1)"),
      literal(10.5f), literal("rgb(255, 0, 0)"),
      literal(15), color(Color.GREEN),
      literal(20), literal(ColorUtils.colorToRgbaString(Color.BLUE)));
    assertEquals("expressions should match", expected, raw(expected.toString()));
  }

  @Test
  public void testRawMatchStrings() {
    Expression expected = match(get("property"), literal(""),
      stop("layer1", "image1"),
      stop("layer2", "image2"));
    assertEquals("expressions should match", expected, raw(expected.toString()));
  }

  @Test
  public void testRawMatchNumbers() {
    Expression expected = match(get("property"), literal(""),
      stop("layer1", 2),
      stop("layer2", 2.7));
    assertEquals("expressions should match", expected, raw(expected.toString()));
  }

  @Test
  public void testAlphaValueInColorConversion() {
    // regression test for #12198
    Expression colorExpression = color(Color.parseColor("#41FF0000")); // 25.4% alpha red
    Object[] result = colorExpression.toArray();
    assertEquals("alpha value should match", 0.254f, (Float) result[4], 0.001f);
  }

  @Test
  public void testAlphaValueInStringConversion() {
    String color = ColorUtils.colorToRgbaString(Color.parseColor("#41FF0000")).split(" ")[3];
    String alpha = color.substring(0, color.length() - 1);
    assertEquals("alpha value should match", 0.254f, Float.valueOf(alpha), 0.001f);
  }

  @Test
  public void testCollator() {
    Object[] expected = new Object[] {"collator",
      new HashMap<String, Object>() {
        {
          put("case-sensitive", true);
          put("diacritic-sensitive", true);
          put("locale", "it-IT");
        }
      }
    };
    Object[] actual = collator(true, true, Locale.ITALY).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testStringCollator() {
    String expected = "[\"collator\", {\"diacritic-sensitive\": true, \"case-sensitive\": true, \"locale\": "
      + "\"it\"}]";
    String actual = collator(true, true, Locale.ITALIAN).toString();
    assertEquals("expression should match", expected, actual);
  }

  @Test
  public void testResolvedLocale() {
    Object[] expected = new Object[] {"resolved-locale",
      new Object[] {"collator",
        new HashMap<String, Object>() {
          {
            put("case-sensitive", false);
            put("diacritic-sensitive", false);
            put("locale", "it");
          }
        }
      }
    };
    Object[] actual = resolvedLocale(collator(false, false, Locale.ITALIAN)).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testRawCollator() {
    Object[] expected = new Object[] {"collator",
      new HashMap<String, Object>() {
        {
          put("case-sensitive", true);
          put("diacritic-sensitive", true);
          put("locale", "it-IT");
        }
      }
    };
    Object[] actual = raw("[\"collator\", {\"diacritic-sensitive\": true, \"case-sensitive\": true, \"locale\": "
      + "\"it-IT\"}]").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testRawCollatorDoubleConversion() {
    Expression expected = collator(false, false, Locale.ITALIAN);
    Object[] actual = raw(expected.toString()).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected.toArray(), actual));
  }

  @Test
  public void testStringNestedCollator() {
    String expected = "[\"collator\", {\"diacritic-sensitive\": [\"==\", 2.0, 1.0], \"case-sensitive\": false,"
      + " \"locale\": \"it\"}]";
    String actual = collator(literal(false), eq(literal(2), literal(1)), literal("it")).toString();
    assertEquals("expression should match", expected, actual);
  }

  @Test
  public void testStringReverseConversion() {
    String expected = "[\"to-string\", [\"get\", \"name_en\"]]";
    String actual = Expression.toString(get("name_en")).toString();
    assertEquals("Reverse string conversion should match", expected, actual);
  }

  @Test
  public void testIsSupportedScriptLiteral() {
    Object[] expected = new Object[] {"is-supported-script", "ಗೌರವಾರ್ಥವಾಗಿ"};
    Object[] actual = isSupportedScript("ಗೌರವಾರ್ಥವಾಗಿ").toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testIsSupportedScriptExpressions() {
    Object[] expected = new Object[] {"is-supported-script", new Object[] {"get", "property_name"}};
    Object[] actual = isSupportedScript(get("property_name")).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testFormatSingleArgument() {
    Object[] expected = new Object[] {"format", "test",
      new TestableExpressionHashMap() {
        {
          put("font-scale", 1.5f);
          put("text-font", new Object[] {"literal", new String[] {"awesome"}});
          put("text-color", new Object[] {"rgb", 255f, 0f, 0f});
        }
      }
    };
    Object[] actual = format(
      formatEntry(
        literal("test"),
        formatFontScale(literal(1.5)),
        formatTextFont(literal(new String[] {"awesome"})),
        formatTextColor(rgb(255, 0, 0))
      )
    ).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  @Test
  public void testFormatMultipleArgument() {
    Object[] expected = new Object[] {
      "format",
      "test",
      new TestableExpressionHashMap() {
        {
          put("text-font", new Object[] {"literal", new String[] {"awesome"}});
        }
      },
      "test2",
      new TestableExpressionHashMap() {
        {
          put("font-scale", 1.5f);
        }
      },
      "test3",
      new TestableExpressionHashMap() {
        {
        }
      },
      "test4",
      new TestableExpressionHashMap() {
        {
          put("text-color", new Object[] {"rgb", 255f, 0f, 0f});
        }
      },
      "test5",
      new TestableExpressionHashMap() {
        {
          put("font-scale", 1.5f);
          put("text-font", new Object[] {"literal", new String[] {"awesome"}});
          put("text-color", new Object[] {"rgb", 255f, 0f, 0f});
        }
      }
    };
    Object[] actual = format(
      formatEntry(literal("test"), formatTextFont(new String[] {"awesome"})),
      formatEntry("test2", formatFontScale(1.5)),
      formatEntry(literal("test3")),
      formatEntry(literal("test4"), formatTextColor(rgb(255, 0, 0))),
      formatEntry(
        literal("test5"),
        formatFontScale(literal(1.5)),
        formatTextFont(new String[] {"awesome"}),
        formatTextColor(rgb(255, 0, 0))
      )
    ).toArray();
    assertTrue("expression should match", Arrays.deepEquals(expected, actual));
  }

  /**
   * This class overrides {@link java.util.AbstractMap#equals(Object)}
   * in order to correctly compare nodes values if they are arrays,
   * which is the case for {@link Expression#format(Expression.FormatEntry...)}'s "text-format" argument.
   */
  private class TestableExpressionHashMap extends HashMap<String, Object> {

    @Override
    public boolean equals(Object o) {
      if (o == this) {
        return true;
      }

      if (!(o instanceof Map)) {
        return false;
      }
      Map<?, ?> m = (Map<?, ?>) o;
      if (m.size() != size()) {
        return false;
      }

      try {
        for (Entry<String, Object> e : entrySet()) {
          String key = e.getKey();
          Object value = e.getValue();
          if (value == null) {
            if (!(m.get(key) == null && m.containsKey(key))) {
              return false;
            }
          } else {
            if (value instanceof Object[]) {
              // Use Arrays.deepEquals() if values are Object arrays.
              if (!Arrays.deepEquals((Object[]) value, (Object[]) m.get(key))) {
                return false;
              }
            } else {
              if (!value.equals(m.get(key))) {
                return false;
              }
            }
          }
        }
      } catch (ClassCastException unused) {
        return false;
      } catch (NullPointerException unused) {
        return false;
      }

      return true;
    }
  }
}