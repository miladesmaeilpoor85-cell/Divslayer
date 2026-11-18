// guardmalloc: an LD_PRELOAD allocator shim that copies the one behaviour of Android's Scudo allocator that matters here.
// Allocations above 64 KiB get their own mapping, placed so that the block ends (16-byte aligned) right before a
// PROT_NONE guard page. Reading even one byte past such a block faults, as it does on a phone, instead of silently
// reading heap memory as glibc does. Everything else goes to glibc.
//   gcc -O2 -shared -fPIC -o guardmalloc.so guardmalloc.c -ldl -lpthread
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <malloc.h>

#define THRESH 65536
#define PAGE 4096
#define TABLE (1 << 18)

typedef struct { uintptr_t ptr; uintptr_t base; size_t maplen; size_t size; } Ent;
static Ent table[TABLE];
static volatile int lock_ = 0;
static void lock(void) { while (__atomic_exchange_n(&lock_, 1, __ATOMIC_ACQUIRE)) {} }
static void unlock(void) { __atomic_store_n(&lock_, 0, __ATOMIC_RELEASE); }

static void *(*real_malloc)(size_t);
static void (*real_free)(void *);
static void *(*real_calloc)(size_t, size_t);
static void *(*real_realloc)(void *, size_t);

static char boot[1 << 16];
static size_t boot_used = 0;
static int in_init = 0;

static void init(void) {
	if (real_malloc || in_init) return;
	in_init = 1;
	real_malloc = dlsym(RTLD_NEXT, "malloc");
	real_free = dlsym(RTLD_NEXT, "free");
	real_calloc = dlsym(RTLD_NEXT, "calloc");
	real_realloc = dlsym(RTLD_NEXT, "realloc");
	in_init = 0;
}

static size_t slot(uintptr_t p) { return (size_t)((p >> 4) * 2654435761u) & (TABLE - 1); }

static void put(uintptr_t p, uintptr_t base, size_t maplen, size_t size) {
	lock();
	size_t i = slot(p);
	while (table[i].ptr && table[i].ptr != (uintptr_t)-1) i = (i + 1) & (TABLE - 1);
	table[i] = (Ent){p, base, maplen, size};
	unlock();
}

static int take(uintptr_t p, Ent *out, int remove) {
	lock();
	size_t i = slot(p);
	while (table[i].ptr) {
		if (table[i].ptr == p) {
			*out = table[i];
			if (remove) table[i].ptr = (uintptr_t)-1;
			unlock();
			return 1;
		}
		i = (i + 1) & (TABLE - 1);
	}
	unlock();
	return 0;
}

static void *guarded(size_t size) {
	size_t rsize = (size + 15) & ~(size_t)15;
	size_t body = (rsize + PAGE - 1) & ~(size_t)(PAGE - 1);
	size_t maplen = body + PAGE;
	char *base = mmap(NULL, maplen, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	if (base == MAP_FAILED) return NULL;
	mprotect(base + body, PAGE, PROT_NONE);
	char *p = base + body - rsize;       // the block ends exactly at the guard page
	put((uintptr_t)p, (uintptr_t)base, maplen, size);
	return p;
}

void *malloc(size_t size) {
	if (!real_malloc) {
		if (in_init) { void *p = boot + boot_used; boot_used += (size + 15) & ~(size_t)15; return p; }
		init();
	}
	if (size > THRESH) return guarded(size);
	return real_malloc(size);
}

void *calloc(size_t n, size_t s) {
	size_t size = n * s;
	if (!real_malloc) {
		if (in_init) { void *p = boot + boot_used; boot_used += (size + 15) & ~(size_t)15; memset(p, 0, size); return p; }
		init();
	}
	if (size > THRESH) return guarded(size);   // fresh anonymous pages are already zero
	return real_calloc(n, s);
}

void free(void *p) {
	if (!p) return;
	if ((char *)p >= boot && (char *)p < boot + sizeof(boot)) return;
	Ent e;
	if (take((uintptr_t)p, &e, 1)) { munmap((void *)e.base, e.maplen); return; }
	if (!real_free) init();
	real_free(p);
}

void *realloc(void *p, size_t size) {
	if (!real_malloc) init();
	if (!p) return malloc(size);
	if (size == 0) { free(p); return NULL; }
	Ent e;
	size_t old = 0;
	int ours = take((uintptr_t)p, &e, 0);
	if (ours) old = e.size;
	else if ((char *)p >= boot && (char *)p < boot + sizeof(boot)) old = size;
	else old = malloc_usable_size(p);
	if (!ours && size <= THRESH && !((char *)p >= boot && (char *)p < boot + sizeof(boot))) return real_realloc(p, size);
	void *n = malloc(size);
	if (!n) return NULL;
	memcpy(n, p, old < size ? old : size);
	free(p);
	return n;
}
