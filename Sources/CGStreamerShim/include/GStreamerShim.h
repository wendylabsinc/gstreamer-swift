#ifndef GSTREAMER_SHIM_H
#define GSTREAMER_SHIM_H

#include <gst/gst.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Initialize GStreamer with no arguments
/// Returns TRUE on success, FALSE on failure
gboolean swift_gst_init(void);

/// Deinitialize GStreamer
void swift_gst_deinit(void);

/// Get the GStreamer version as a string (caller must g_free the result)
gchar* swift_gst_version_string(void);

/// Get the major version number
guint swift_gst_version_major(void);

/// Get the minor version number
guint swift_gst_version_minor(void);

/// Get the micro version number
guint swift_gst_version_micro(void);

/// Get the nano version number
guint swift_gst_version_nano(void);

/// Parse a pipeline description and return a GstElement (pipeline)
/// Returns NULL on error, error_message will be set (caller must g_free)
GstElement* swift_gst_parse_launch(const gchar* pipeline_description, gchar** error_message);

/// Get element by name from a bin/pipeline
GstElement* swift_gst_bin_get_by_name(GstElement* bin, const gchar* name);

/// Set pipeline state
GstStateChangeReturn swift_gst_element_set_state(GstElement* element, GstState state);

/// Get pipeline state
GstState swift_gst_element_get_state(GstElement* element, GstClockTime timeout);

/// Get the bus from an element
GstBus* swift_gst_element_get_bus(GstElement* element);

/// Pop a message from the bus (non-blocking)
GstMessage* swift_gst_bus_pop(GstBus* bus);

/// Pop a message from the bus with timeout
GstMessage* swift_gst_bus_timed_pop(GstBus* bus, GstClockTime timeout);

/// Pop a message from the bus filtered by type
GstMessage* swift_gst_bus_timed_pop_filtered(GstBus* bus, GstClockTime timeout, GstMessageType types);

/// Get message type
GstMessageType swift_gst_message_type(GstMessage* message);

/// Get message type name
const gchar* swift_gst_message_type_name(GstMessage* message);

/// Parse error message (caller must g_free error_string and debug_string)
void swift_gst_message_parse_error(GstMessage* message, gchar** error_string, gchar** debug_string);

/// Parse warning message (caller must g_free warning_string and debug_string)
void swift_gst_message_parse_warning(GstMessage* message, gchar** warning_string, gchar** debug_string);

/// Parse info message (caller must g_free info_string and debug_string)
void swift_gst_message_parse_info(GstMessage* message, gchar** info_string, gchar** debug_string);

/// Unref a message
void swift_gst_message_unref(GstMessage* message);

/// Unref an element
void swift_gst_object_unref(gpointer object);

/// Link two elements
gboolean swift_gst_element_link(GstElement* src, GstElement* dest);

/// Get element name (caller must g_free)
gchar* swift_gst_element_get_name(GstElement* element);

/// Get element factory name
const gchar* swift_gst_element_factory_get_name(GstElement* element);

/// Create a caps from string
GstCaps* swift_gst_caps_from_string(const gchar* string);

/// Convert caps to string (caller must g_free)
gchar* swift_gst_caps_to_string(GstCaps* caps);

/// Unref caps
void swift_gst_caps_unref(GstCaps* caps);

/// Set element property (boolean)
void swift_gst_element_set_bool(GstElement* element, const gchar* name, gboolean value);

/// Set element property (integer)
void swift_gst_element_set_int(GstElement* element, const gchar* name, gint value);

/// Set element property (string)
void swift_gst_element_set_string(GstElement* element, const gchar* name, const gchar* value);

/// Set element property (double)
void swift_gst_element_set_double(GstElement* element, const gchar* name, gdouble value);

/// Get element property (boolean)
/// Returns the value, or FALSE if property doesn't exist
gboolean swift_gst_element_get_bool(GstElement* element, const gchar* name);

/// Get element property (integer)
/// Returns the value, or 0 if property doesn't exist
gint swift_gst_element_get_int(GstElement* element, const gchar* name);

/// Get element property (string) - caller must g_free
/// Returns NULL if property doesn't exist
gchar* swift_gst_element_get_string(GstElement* element, const gchar* name);

/// Get element property (double)
/// Returns the value, or 0.0 if property doesn't exist
gdouble swift_gst_element_get_double(GstElement* element, const gchar* name);

/// Parse state changed message
void swift_gst_message_parse_state_changed(GstMessage* message, GstState* old_state, GstState* new_state, GstState* pending);

// MARK: - Position and Duration Queries

/// Query current position in nanoseconds
/// Returns TRUE on success, FALSE on failure
gboolean swift_gst_element_query_position(GstElement* element, gint64* position);

/// Query duration in nanoseconds
/// Returns TRUE on success, FALSE on failure
gboolean swift_gst_element_query_duration(GstElement* element, gint64* duration);

// MARK: - Seeking

/// Seek to a position in nanoseconds
/// Returns TRUE on success, FALSE on failure
gboolean swift_gst_element_seek_simple(GstElement* element, gint64 position);

/// Seek with full control (flags, start, stop)
/// Returns TRUE on success, FALSE on failure
gboolean swift_gst_element_seek(GstElement* element, gdouble rate, gint64 start, gint64 stop, GstSeekFlags flags);

/// Seek flags helper - get flush flag
GstSeekFlags swift_gst_seek_flag_flush(void);

/// Seek flags helper - get key unit flag
GstSeekFlags swift_gst_seek_flag_key_unit(void);

/// Seek flags helper - get accurate flag
GstSeekFlags swift_gst_seek_flag_accurate(void);

// MARK: - Tee and Dynamic Pipelines

/// Create an element by factory name
GstElement* swift_gst_element_factory_make(const gchar* factory_name, const gchar* name);

/// Add an element to a bin
gboolean swift_gst_bin_add(GstElement* bin, GstElement* element);

/// Remove an element from a bin
gboolean swift_gst_bin_remove(GstElement* bin, GstElement* element);

/// Request a pad from an element (e.g., tee)
GstPad* swift_gst_element_request_pad_simple(GstElement* element, const gchar* name);

/// Release a request pad
void swift_gst_element_release_request_pad(GstElement* element, GstPad* pad);

/// Get a static pad from an element
GstPad* swift_gst_element_get_static_pad(GstElement* element, const gchar* name);

/// Link two pads
gboolean swift_gst_pad_link(GstPad* src, GstPad* sink);

/// Unlink two pads
gboolean swift_gst_pad_unlink(GstPad* src, GstPad* sink);

/// Unref a pad
void swift_gst_pad_unref(GstPad* pad);

/// Sync element state with parent
gboolean swift_gst_element_sync_state_with_parent(GstElement* element);

// MARK: - Device Monitor

/// Create a new device monitor
GstDeviceMonitor* swift_gst_device_monitor_new(void);

/// Add a filter to the device monitor (e.g., "Video/Source", "Audio/Source")
/// Returns the filter ID, or 0 on failure
guint swift_gst_device_monitor_add_filter(GstDeviceMonitor* monitor, const gchar* classes, GstCaps* caps);

/// Start the device monitor
gboolean swift_gst_device_monitor_start(GstDeviceMonitor* monitor);

/// Stop the device monitor
void swift_gst_device_monitor_stop(GstDeviceMonitor* monitor);

/// Get devices from the monitor (returns a GList of GstDevice*)
GList* swift_gst_device_monitor_get_devices(GstDeviceMonitor* monitor);

/// Get device display name (caller must g_free)
gchar* swift_gst_device_get_display_name(GstDevice* device);

/// Get device class (e.g., "Video/Source")
const gchar* swift_gst_device_get_device_class(GstDevice* device);

/// Get device caps
GstCaps* swift_gst_device_get_caps(GstDevice* device);

/// Create an element for the device
GstElement* swift_gst_device_create_element(GstDevice* device, const gchar* name);

/// Get a string property from device properties (caller must g_free)
gchar* swift_gst_device_get_property_string(GstDevice* device, const gchar* name);

/// Unref a device
void swift_gst_device_unref(GstDevice* device);

/// Unref a device monitor
void swift_gst_device_monitor_unref(GstDeviceMonitor* monitor);

/// Free a GList of devices
void swift_gst_device_list_free(GList* list);

#ifdef __cplusplus
}
#endif

#endif /* GSTREAMER_SHIM_H */
