#ifndef FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_
#define FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

typedef struct _V2rayBoxPlugin V2rayBoxPlugin;
typedef struct {
  GObjectClass parent_class;
} V2rayBoxPluginClass;

FLUTTER_PLUGIN_EXPORT GType v2ray_box_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void v2ray_box_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_
