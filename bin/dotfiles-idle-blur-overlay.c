#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <linux/memfd.h>
#include <fcntl.h>
#include <wayland-client.h>
#include <wayland-client-protocol.h>
#include "wlr-layer-shell-unstable-v1-client-protocol.h"

// memfd_create wrapper for systems without glibc 2.27+
static int memfd_create(const char *name, unsigned int flags) {
    return syscall(SYS_memfd_create, name, flags);
}

static int running = 1;

static void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

static void layer_surface_configure(void *data,
                                    struct zwlr_layer_surface_v1 *surface,
                                    uint32_t serial,
                                    uint32_t width,
                                    uint32_t height) {
    (void)data;
    (void)width;
    (void)height;
    zwlr_layer_surface_v1_ack_configure(surface, serial);
}

static void layer_surface_closed(void *data,
                                 struct zwlr_layer_surface_v1 *surface) {
    (void)data;
    (void)surface;
    running = 0;
}

static const struct zwlr_layer_surface_v1_listener layer_surface_listener = {
    .configure = layer_surface_configure,
    .closed = layer_surface_closed,
};

// Registry listener data structure
struct registry_data {
    struct wl_compositor *compositor;
    struct zwlr_layer_shell_v1 *layer_shell;
    struct wl_shm *shm;
};

static void registry_global(void *data, struct wl_registry *registry,
                            uint32_t name, const char *interface,
                            uint32_t version) {
    (void)version;
    struct registry_data *rd = data;

    if (strcmp(interface, wl_compositor_interface.name) == 0) {
        rd->compositor = (struct wl_compositor *)
            wl_registry_bind(registry, name, &wl_compositor_interface, 4);
    } else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
        rd->layer_shell = (struct zwlr_layer_shell_v1 *)
            wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, 4);
    } else if (strcmp(interface, wl_shm_interface.name) == 0) {
        rd->shm = (struct wl_shm *)
            wl_registry_bind(registry, name, &wl_shm_interface, 1);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry,
                                    uint32_t name) {
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

int main(void) {
    struct wl_display *display;
    struct wl_compositor *compositor;
    struct wl_surface *surface;
    struct zwlr_layer_shell_v1 *layer_shell;
    struct zwlr_layer_surface_v1 *layer_surface;
    struct wl_shm *shm;
    struct wl_shm_pool *pool;
    struct wl_buffer *buffer;
    void *data;
    int width = 1, height = 1;
    int stride = width * 4;
    int size = stride * height;
    int fd;

    // Setup signal handlers
    signal(SIGTERM, handle_signal);
    signal(SIGINT, handle_signal);

    // Connect to Wayland display
    display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "Failed to connect to Wayland display\n");
        return 1;
    }

    // Get registry
    struct registry_data registry_data = {0};
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, &registry_data);
    wl_display_roundtrip(display);

    compositor = registry_data.compositor;
    layer_shell = registry_data.layer_shell;
    shm = registry_data.shm;

    if (!compositor || !layer_shell || !shm) {
        fprintf(stderr, "Failed to get required Wayland interfaces\n");
        wl_display_disconnect(display);
        return 1;
    }

    // Create surface
    surface = wl_compositor_create_surface(compositor);
    if (!surface) {
        fprintf(stderr, "Failed to create surface\n");
        wl_display_disconnect(display);
        return 1;
    }

    // Create layer surface
    struct wl_output *output = NULL; // NULL means all outputs
    layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        layer_shell, surface, output,
        ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "dotfiles-idle-blur");

    if (!layer_surface) {
        fprintf(stderr, "Failed to create layer surface\n");
        wl_surface_destroy(surface);
        wl_display_disconnect(display);
        return 1;
    }

    // Configure layer surface
    zwlr_layer_surface_v1_set_size(layer_surface, 0, 0);
    zwlr_layer_surface_v1_set_anchor(layer_surface,
                                      ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
                                      ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
                                      ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                                      ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    zwlr_layer_surface_v1_set_exclusive_zone(layer_surface, -1);
    zwlr_layer_surface_v1_set_keyboard_interactivity(layer_surface, 0);
    zwlr_layer_surface_v1_add_listener(layer_surface, &layer_surface_listener, NULL);

    // Create shared memory buffer
    fd = memfd_create("dotfiles-idle-blur", MFD_CLOEXEC | MFD_ALLOW_SEALING);
    if (fd < 0) {
        fprintf(stderr, "Failed to create memfd\n");
        zwlr_layer_surface_v1_destroy(layer_surface);
        wl_surface_destroy(surface);
        wl_display_disconnect(display);
        return 1;
    }

    if (ftruncate(fd, size) < 0) {
        fprintf(stderr, "Failed to truncate memfd\n");
        close(fd);
        zwlr_layer_surface_v1_destroy(layer_surface);
        wl_surface_destroy(surface);
        wl_display_disconnect(display);
        return 1;
    }

    data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (data == MAP_FAILED) {
        fprintf(stderr, "Failed to mmap buffer\n");
        close(fd);
        zwlr_layer_surface_v1_destroy(layer_surface);
        wl_surface_destroy(surface);
        wl_display_disconnect(display);
        return 1;
    }

    // Fill buffer with fully transparent pixels (ARGB32: A=0, R=0, G=0, B=0)
    memset(data, 0, size);

    pool = wl_shm_create_pool(shm, fd, size);
    buffer = wl_shm_pool_create_buffer(pool, 0, width, height, stride,
                                       WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);

    // Attach buffer to surface
    wl_surface_attach(surface, buffer, 0, 0);
    wl_surface_commit(surface);
    wl_display_roundtrip(display);

    // Event loop
    while (running && wl_display_dispatch(display) != -1) {
        // Continue running until signal received
    }

    // Cleanup
    munmap(data, size);
    wl_buffer_destroy(buffer);
    zwlr_layer_surface_v1_destroy(layer_surface);
    wl_surface_destroy(surface);
    wl_display_disconnect(display);

    return 0;
}
