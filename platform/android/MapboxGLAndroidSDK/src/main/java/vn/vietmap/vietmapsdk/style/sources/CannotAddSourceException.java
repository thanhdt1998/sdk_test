package vn.vietmap.vietmapsdk.style.sources;

import androidx.annotation.Keep;

/**
 * Thrown when adding a source to a map twice
 */
@Keep
public class CannotAddSourceException extends RuntimeException {

  public CannotAddSourceException(String message) {
    super(message);
  }

}
