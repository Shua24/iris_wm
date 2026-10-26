/*  Ground truth for the list primitives Iris depends on.
 *
 *  The question this answers: after wl_list_remove, does the removed element
 *  point at itself (making a second remove a no-op), or does wayland null its
 *  links (making a second remove a null dereference)?
 *
 *  Guessing wrong here is the difference between an idempotent teardown and a
 *  segfault during shutdown, so it is measured rather than assumed.
 *
 *  Build and run from the repository root:
 *    gcc $(pkg-config --cflags wayland-server) -o /tmp/list_semantics \
 *        tests/c_list_semantics.c $(pkg-config --libs wayland-server)
 *    /tmp/list_semantics
 */

#include <stdio.h>
#include <wayland-server-core.h>

static void show(const char *label, struct wl_list *element)
{
	printf("%-28s prev=%s next=%s empty=%d\n",
	       label,
	       element->prev == element ? "self" :
	       (element->prev == NULL ? "NULL" : "other"),
	       element->next == element ? "self" :
	       (element->next == NULL ? "NULL" : "other"),
	       wl_list_empty(element));
}

int main(void)
{
	struct wl_signal signal;
	struct wl_listener first = {0};
	struct wl_listener second = {0};

	wl_signal_init(&signal);
	printf("after init: signal empty=%d length=%zu\n",
	       wl_list_empty(&signal.listener_list),
	       wl_list_length(&signal.listener_list));

	wl_signal_add(&signal, &first);
	wl_signal_add(&signal, &second);
	printf("after two adds: length=%zu\n",
	       wl_list_length(&signal.listener_list));

	show("first.link while linked", &first.link);
	show("second.link while linked", &second.link);

	wl_list_remove(&first.link);
	show("first.link after remove", &first.link);
	printf("after one remove: length=%zu\n",
	       wl_list_length(&signal.listener_list));

	wl_list_remove(&second.link);
	show("second.link after remove", &second.link);
	printf("after two removes: length=%zu empty=%d\n",
	       wl_list_length(&signal.listener_list),
	       wl_list_empty(&signal.listener_list));

	/* The dangerous case, deliberately last: if removal nulls the links this
	 * segfaults, which is exactly the behaviour Iris must guard against. */
	printf("about to remove an already-removed element...\n");
	fflush(stdout);
	wl_list_remove(&second.link);
	printf("survived a double remove\n");

	return 0;
}
