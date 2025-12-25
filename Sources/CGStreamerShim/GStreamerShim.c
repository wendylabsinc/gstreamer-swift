#include "include/GStreamerShim.h"
#include <string.h>

gboolean swift_gst_init(void) {
    GError* error = NULL;
    gboolean result = gst_init_check(NULL, NULL, &error);
    if (error) {
        g_error_free(error);
    }
    return result;
}

void swift_gst_deinit(void) {
    gst_deinit();
}

gchar* swift_gst_version_string(void) {
    return gst_version_string();
}

guint swift_gst_version_major(void) {
    guint major, minor, micro, nano;
    gst_version(&major, &minor, &micro, &nano);
    return major;
}

guint swift_gst_version_minor(void) {
    guint major, minor, micro, nano;
    gst_version(&major, &minor, &micro, &nano);
    return minor;
}

guint swift_gst_version_micro(void) {
    guint major, minor, micro, nano;
    gst_version(&major, &minor, &micro, &nano);
    return micro;
}

guint swift_gst_version_nano(void) {
    guint major, minor, micro, nano;
    gst_version(&major, &minor, &micro, &nano);
    return nano;
}

GstElement* swift_gst_parse_launch(const gchar* pipeline_description, gchar** error_message) {
    GError* error = NULL;
    GstElement* pipeline = gst_parse_launch(pipeline_description, &error);

    if (error) {
        if (error_message) {
            *error_message = g_strdup(error->message);
        }
        g_error_free(error);
    } else if (error_message) {
        *error_message = NULL;
    }

    return pipeline;
}

GstElement* swift_gst_bin_get_by_name(GstElement* bin, const gchar* name) {
    if (!GST_IS_BIN(bin)) {
        return NULL;
    }
    return gst_bin_get_by_name(GST_BIN(bin), name);
}

GstStateChangeReturn swift_gst_element_set_state(GstElement* element, GstState state) {
    return gst_element_set_state(element, state);
}

GstState swift_gst_element_get_state(GstElement* element, GstClockTime timeout) {
    GstState state;
    gst_element_get_state(element, &state, NULL, timeout);
    return state;
}

GstBus* swift_gst_element_get_bus(GstElement* element) {
    return gst_element_get_bus(element);
}

GstMessage* swift_gst_bus_pop(GstBus* bus) {
    return gst_bus_pop(bus);
}

GstMessage* swift_gst_bus_timed_pop(GstBus* bus, GstClockTime timeout) {
    return gst_bus_timed_pop(bus, timeout);
}

GstMessage* swift_gst_bus_timed_pop_filtered(GstBus* bus, GstClockTime timeout, GstMessageType types) {
    return gst_bus_timed_pop_filtered(bus, timeout, types);
}

GstMessageType swift_gst_message_type(GstMessage* message) {
    return GST_MESSAGE_TYPE(message);
}

const gchar* swift_gst_message_type_name(GstMessage* message) {
    return GST_MESSAGE_TYPE_NAME(message);
}

void swift_gst_message_parse_error(GstMessage* message, gchar** error_string, gchar** debug_string) {
    GError* error = NULL;
    gchar* debug = NULL;

    gst_message_parse_error(message, &error, &debug);

    if (error_string) {
        *error_string = error ? g_strdup(error->message) : NULL;
    }
    if (debug_string) {
        *debug_string = debug;
    } else {
        g_free(debug);
    }

    if (error) {
        g_error_free(error);
    }
}

void swift_gst_message_parse_warning(GstMessage* message, gchar** warning_string, gchar** debug_string) {
    GError* error = NULL;
    gchar* debug = NULL;

    gst_message_parse_warning(message, &error, &debug);

    if (warning_string) {
        *warning_string = error ? g_strdup(error->message) : NULL;
    }
    if (debug_string) {
        *debug_string = debug;
    } else {
        g_free(debug);
    }

    if (error) {
        g_error_free(error);
    }
}

void swift_gst_message_parse_info(GstMessage* message, gchar** info_string, gchar** debug_string) {
    GError* error = NULL;
    gchar* debug = NULL;

    gst_message_parse_info(message, &error, &debug);

    if (info_string) {
        *info_string = error ? g_strdup(error->message) : NULL;
    }
    if (debug_string) {
        *debug_string = debug;
    } else {
        g_free(debug);
    }

    if (error) {
        g_error_free(error);
    }
}

void swift_gst_message_unref(GstMessage* message) {
    gst_message_unref(message);
}

void swift_gst_object_unref(gpointer object) {
    gst_object_unref(object);
}

gboolean swift_gst_element_link(GstElement* src, GstElement* dest) {
    return gst_element_link(src, dest);
}

gchar* swift_gst_element_get_name(GstElement* element) {
    return gst_element_get_name(element);
}

const gchar* swift_gst_element_factory_get_name(GstElement* element) {
    GstElementFactory* factory = gst_element_get_factory(element);
    if (factory) {
        return gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory));
    }
    return NULL;
}

GstCaps* swift_gst_caps_from_string(const gchar* string) {
    return gst_caps_from_string(string);
}

gchar* swift_gst_caps_to_string(GstCaps* caps) {
    return gst_caps_to_string(caps);
}

void swift_gst_caps_unref(GstCaps* caps) {
    gst_caps_unref(caps);
}

void swift_gst_element_set_bool(GstElement* element, const gchar* name, gboolean value) {
    g_object_set(G_OBJECT(element), name, value, NULL);
}

void swift_gst_element_set_int(GstElement* element, const gchar* name, gint value) {
    g_object_set(G_OBJECT(element), name, value, NULL);
}

void swift_gst_element_set_string(GstElement* element, const gchar* name, const gchar* value) {
    g_object_set(G_OBJECT(element), name, value, NULL);
}

void swift_gst_message_parse_state_changed(GstMessage* message, GstState* old_state, GstState* new_state, GstState* pending) {
    gst_message_parse_state_changed(message, old_state, new_state, pending);
}

// MARK: - Position and Duration Queries

gboolean swift_gst_element_query_position(GstElement* element, gint64* position) {
    return gst_element_query_position(element, GST_FORMAT_TIME, position);
}

gboolean swift_gst_element_query_duration(GstElement* element, gint64* duration) {
    return gst_element_query_duration(element, GST_FORMAT_TIME, duration);
}

// MARK: - Seeking

gboolean swift_gst_element_seek_simple(GstElement* element, gint64 position) {
    return gst_element_seek_simple(
        element,
        GST_FORMAT_TIME,
        GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT,
        position
    );
}

gboolean swift_gst_element_seek(GstElement* element, gdouble rate, gint64 start, gint64 stop, GstSeekFlags flags) {
    return gst_element_seek(
        element,
        rate,
        GST_FORMAT_TIME,
        flags,
        GST_SEEK_TYPE_SET, start,
        stop >= 0 ? GST_SEEK_TYPE_SET : GST_SEEK_TYPE_NONE, stop
    );
}

GstSeekFlags swift_gst_seek_flag_flush(void) {
    return GST_SEEK_FLAG_FLUSH;
}

GstSeekFlags swift_gst_seek_flag_key_unit(void) {
    return GST_SEEK_FLAG_KEY_UNIT;
}

GstSeekFlags swift_gst_seek_flag_accurate(void) {
    return GST_SEEK_FLAG_ACCURATE;
}

// MARK: - Tee and Dynamic Pipelines

GstElement* swift_gst_element_factory_make(const gchar* factory_name, const gchar* name) {
    return gst_element_factory_make(factory_name, name);
}

gboolean swift_gst_bin_add(GstElement* bin, GstElement* element) {
    if (!GST_IS_BIN(bin)) {
        return FALSE;
    }
    return gst_bin_add(GST_BIN(bin), element);
}

gboolean swift_gst_bin_remove(GstElement* bin, GstElement* element) {
    if (!GST_IS_BIN(bin)) {
        return FALSE;
    }
    return gst_bin_remove(GST_BIN(bin), element);
}

GstPad* swift_gst_element_request_pad_simple(GstElement* element, const gchar* name) {
    return gst_element_request_pad_simple(element, name);
}

void swift_gst_element_release_request_pad(GstElement* element, GstPad* pad) {
    gst_element_release_request_pad(element, pad);
}

GstPad* swift_gst_element_get_static_pad(GstElement* element, const gchar* name) {
    return gst_element_get_static_pad(element, name);
}

gboolean swift_gst_pad_link(GstPad* src, GstPad* sink) {
    return gst_pad_link(src, sink) == GST_PAD_LINK_OK;
}

gboolean swift_gst_pad_unlink(GstPad* src, GstPad* sink) {
    return gst_pad_unlink(src, sink);
}

void swift_gst_pad_unref(GstPad* pad) {
    gst_object_unref(pad);
}

gboolean swift_gst_element_sync_state_with_parent(GstElement* element) {
    return gst_element_sync_state_with_parent(element);
}
