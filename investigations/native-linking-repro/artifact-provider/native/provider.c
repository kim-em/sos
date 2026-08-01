#include <lean/lean.h>

extern unsigned artifact_secondary_value(void);

LEAN_EXPORT lean_obj_res artifact_provider_value(b_lean_obj_arg unit) {
    (void)unit;
    return lean_box(artifact_secondary_value());
}
