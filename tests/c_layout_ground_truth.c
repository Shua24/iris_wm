/*  Ground truth for the struct mirrors in src/wlroots/.
 *
 *  Build and run from the repository root:
 *    gcc -DWLR_USE_UNSTABLE $(pkg-config --cflags wlroots-0.20 wayland-server) \
 *        -o /tmp/offsets tests/c_layout_ground_truth.c
 *    /tmp/offsets
 *
 *  Every offset printed here must match the Ada-side offsets printed by
 *  tests/binding_probe. A mismatch is a silent state corruption, not a crash.
 */

#include <stddef.h>
#include <stdio.h>
#include <wayland-server-core.h>
#include <wlr/backend.h>
#include <wlr/util/box.h>

int main(void)
{
	printf("sizeof wl_list     %zu\n", sizeof(struct wl_list));
	printf("sizeof wl_listener %zu\n", sizeof(struct wl_listener));
	printf("sizeof wl_signal   %zu\n", sizeof(struct wl_signal));
	printf("wl_listener.link   %zu\n", offsetof(struct wl_listener, link));
	printf("wl_listener.notify %zu\n", offsetof(struct wl_listener, notify));
	printf("wl_signal.listener_list %zu\n",
		offsetof(struct wl_signal, listener_list));

	printf("sizeof wlr_backend %zu\n", sizeof(struct wlr_backend));
	printf("wlr_backend.impl   %zu\n", offsetof(struct wlr_backend, impl));
	printf("wlr_backend.buffer_caps %zu\n",
		offsetof(struct wlr_backend, buffer_caps));
	printf("wlr_backend.features.timeline %zu\n",
		offsetof(struct wlr_backend, features.timeline));
	printf("wlr_backend.events.destroy %zu\n",
		offsetof(struct wlr_backend, events.destroy));
	printf("wlr_backend.events.new_input %zu\n",
		offsetof(struct wlr_backend, events.new_input));
	printf("wlr_backend.events.new_output %zu\n",
		offsetof(struct wlr_backend, events.new_output));

	printf("sizeof wlr_box     %zu\n", sizeof(struct wlr_box));
	printf("wlr_box.x          %zu\n", offsetof(struct wlr_box, x));
	printf("wlr_box.y          %zu\n", offsetof(struct wlr_box, y));
	printf("wlr_box.width      %zu\n", offsetof(struct wlr_box, width));
	printf("wlr_box.height     %zu\n", offsetof(struct wlr_box, height));

	return 0;
}
