#include <lean/lean.h>

extern unsigned secondary_value(void);

LEAN_EXPORT lean_obj_res provider_value(b_lean_obj_arg unit) {
    (void)unit;
    return lean_box(secondary_value());
}
