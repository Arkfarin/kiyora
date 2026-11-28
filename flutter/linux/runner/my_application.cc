#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

struct WindowState {
  gint width;
  gint height;
  gboolean maximized;
  gboolean first_frame_ready;
  gboolean preferences_ready;
  gulong maximize_after_paint;
  gboolean first_paint_done;
  gboolean pending_maximize;
};

static void request_restored_maximize(GtkWidget* widget, WindowState* state) {
  if (!state->first_paint_done || !state->pending_maximize) return;
  state->pending_maximize = FALSE;
  g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, [](gpointer data) -> gboolean {
    auto* window = GTK_WIDGET(data);
    if (gtk_widget_get_realized(window)) gtk_window_maximize(GTK_WINDOW(window));
    return G_SOURCE_REMOVE;
  }, g_object_ref(widget), g_object_unref);
}

static gboolean window_configured(GtkWidget* widget, GdkEventConfigure* event,
                                  gpointer user_data) {
  auto* state = static_cast<WindowState*>(user_data);
  GdkWindow* native = gtk_widget_get_window(widget);
  const auto flags = native ? gdk_window_get_state(native) : GDK_WINDOW_STATE_WITHDRAWN;
  request_restored_maximize(widget, state);
  // Keep the normal size while maximized, fullscreen or minimized.
  if (!(flags & (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN |
                 GDK_WINDOW_STATE_ICONIFIED)) &&
      event->width >= 720 && event->height >= 540) {
    state->width = event->width;
    state->height = event->height;
  }
  return FALSE;
}

static gboolean window_state_changed(GtkWidget* widget, GdkEventWindowState* event,
                                     gpointer user_data) {
  auto* state = static_cast<WindowState*>(user_data);
  state->maximized = (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
  request_restored_maximize(widget, state);
  return FALSE;
}

static void maximize_after_first_paint(GdkFrameClock* clock, gpointer user_data) {
  auto* window = GTK_WIDGET(user_data);
  if (!gtk_widget_get_mapped(window)) return;
  auto* state = static_cast<WindowState*>(g_object_get_data(G_OBJECT(window), "kiyora-window-state"));
  const gulong handler = state->maximize_after_paint;
  state->maximize_after_paint = 0;
  if (handler) g_signal_handler_disconnect(clock, handler);
  state->first_paint_done = TRUE;
}

static void host_method_call(FlMethodChannel* channel, FlMethodCall* call,
                             gpointer user_data) {
  auto* window = GTK_WINDOW(user_data);
  auto* state = static_cast<WindowState*>(g_object_get_data(G_OBJECT(window), "kiyora-window-state"));
  const gchar* name = fl_method_call_get_name(call);
  if (g_strcmp0(name, "raise") == 0) {
    gtk_window_present(window);
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else if (g_strcmp0(name, "windowState") == 0) {
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "width", fl_value_new_int(state->width));
    fl_value_set_string_take(result, "height", fl_value_new_int(state->height));
    fl_value_set_string_take(result, "maximized", fl_value_new_bool(state->maximized));
    fl_method_call_respond_success(call, result, nullptr);
  } else if (g_strcmp0(name, "restoreWindow") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    FlValue* width = fl_value_get_type(args) == FL_VALUE_TYPE_MAP
        ? fl_value_lookup_string(args, "width") : nullptr;
    FlValue* height = fl_value_get_type(args) == FL_VALUE_TYPE_MAP
        ? fl_value_lookup_string(args, "height") : nullptr;
    FlValue* maximized = fl_value_get_type(args) == FL_VALUE_TYPE_MAP
        ? fl_value_lookup_string(args, "maximized") : nullptr;
    if (!width || !height || !maximized ||
        fl_value_get_type(width) != FL_VALUE_TYPE_INT ||
        fl_value_get_type(height) != FL_VALUE_TYPE_INT ||
        fl_value_get_type(maximized) != FL_VALUE_TYPE_BOOL) {
      fl_method_call_respond_error(call, "InvalidWindowState", "Invalid window preferences", nullptr, nullptr);
      return;
    }
    state->width = static_cast<gint>(CLAMP(fl_value_get_int(width), 720, 7680));
    state->height = static_cast<gint>(CLAMP(fl_value_get_int(height), 540, 4320));
    GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
    GdkMonitor* monitor = gdk_display_get_monitor_at_window(display, gtk_widget_get_window(GTK_WIDGET(window)));
    if (monitor) {
      GdkRectangle area;
      gdk_monitor_get_workarea(monitor, &area);
      state->width = MIN(state->width, MAX(720, area.width));
      state->height = MIN(state->height, MAX(540, area.height));
    }
    gtk_window_set_default_size(window, state->width, state->height);
    gtk_window_resize(window, state->width, state->height);
    state->maximized = fl_value_get_bool(maximized);
    state->pending_maximize = state->maximized;
    if (state->maximized) {
      // Wait for a compositor configure/state event after the first paint.
      // A request sent with the first surface commit can arrive before mapping.
      GdkFrameClock* clock = gtk_widget_get_frame_clock(GTK_WIDGET(window));
      if (clock) {
        if (state->maximize_after_paint) g_signal_handler_disconnect(clock, state->maximize_after_paint);
        state->maximize_after_paint = g_signal_connect_object(clock, "after-paint",
            G_CALLBACK(maximize_after_first_paint), window, G_CONNECT_AFTER);
      } else {
        gtk_window_maximize(window);
      }
    } else {
      gtk_window_unmaximize(window);
    }
    state->preferences_ready = TRUE;
    if (state->first_frame_ready) gtk_widget_show(GTK_WIDGET(window));
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWidget* window = gtk_widget_get_toplevel(GTK_WIDGET(view));
  auto* state = static_cast<WindowState*>(g_object_get_data(G_OBJECT(window), "kiyora-window-state"));
  state->first_frame_ready = TRUE;
  // Do not map the surface with default geometry while Dart is still loading
  // saved preferences. Wayland controls geometry once a surface is mapped.
  if (state->preferences_ready) gtk_widget_show(window);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_default_size(window, 1280, 720);
  auto* state = g_new0(WindowState, 1);
  state->width = 1280;
  state->height = 720;
  g_object_set_data_full(G_OBJECT(window), "kiyora-window-state", state, g_free);
  g_signal_connect(window, "configure-event", G_CALLBACK(window_configured), state);
  g_signal_connect(window, "window-state-event", G_CALLBACK(window_state_changed), state);
  // Keep the desktop transport and navigation usable when the window shrinks.
  GdkGeometry geometry = {};
  geometry.min_width = 720;
  geometry.min_height = 540;
  gtk_window_set_geometry_hints(window, nullptr, &geometry, GDK_HINT_MIN_SIZE);

  // If you want to use a header bar, uncomment the following lines.
  // Header bars are commonly used in GNOME based desktop environments and
  // allow additional widgets to be added to the title bar.
  // See https://docs.gtk.org/gtk3/class.HeaderBar.html
  // GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  // gtk_widget_show(GTK_WIDGET(header_bar));
  // gtk_header_bar_set_show_close_button(header_bar, TRUE);
  // gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));

  gtk_window_set_title(window, "KIYORA");

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) host = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "io.github.arkfarin.kiyora/host", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(host, host_method_call,
      g_object_ref(window), g_object_unref);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
