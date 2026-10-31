/* cgl-probe.c — OpenGL acceleration status probe for the TGL GLDriver experiment (docs/OPENGL.md).
 *
 * Mirrors JulioNectar's #21 repro: does CGL hand out an ACCELERATED pixel format, and which
 * renderer backs a created context? Exit codes: 0 = accelerated context ok, 1 = software only,
 * 2 = no context at all. Build (needs Command Line Tools):  clang -framework OpenGL -o cgl-probe cgl-probe.c
 */
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl.h>
#include <stdio.h>
#include <stdlib.h>

static const char *cgl_err(int e)
{
    switch (e) {
    case 0:     return "ok";
    case 10002: return "kCGLBadPixelFormat";
    case 10004: return "kCGLBadContext";
    case 10000: return "kCGLBadAttribute";
    default:    return "CGL error (see CGLError enum)";
    }
}

static void dump_renderer(const char *tag)
{
    const char *vendor  = glGetString(GL_VENDOR);
    const char *rend    = glGetString(GL_RENDERER);
    const char *ver     = glGetString(GL_VERSION);
    const char *glsl    = glGetString(GL_SHADING_LANGUAGE_VERSION);
    printf("  [%s] GL_VENDOR=%s\n",        tag, vendor ? vendor : "(null)");
    printf("  [%s] GL_RENDERER=%s\n",      tag, rend   ? rend   : "(null)");
    printf("  [%s] GL_VERSION=%s\n",       tag, ver    ? ver    : "(null)");
    printf("  [%s] GL_SHADING_LANGUAGE=%s\n", tag, glsl ? glsl : "(null)");
}

static int try_format(const char *tag, CGLPixelFormatAttribute *attrs)
{
    CGLPixelFormatObj pf = NULL;
    GLint n = 0;
    CGLError err = CGLChoosePixelFormat(attrs, &pf, &n);
    printf("  [%s] CGLChoosePixelFormat -> err=%d (%s), %d format(s)\n",
           tag, err, cgl_err(err), (int)n);
    if (n < 1 || !pf) return 0;

    CGLContextObj ctx = NULL;
    err = CGLCreateContext(pf, NULL, &ctx);
    CGLDestroyPixelFormat(pf);
    printf("  [%s] CGLCreateContext -> err=%d (%s)\n", tag, err, cgl_err(err));
    if (err || !ctx) return 0;

    CGLSetCurrentContext(ctx);
    dump_renderer(tag);
    CGLSetCurrentContext(NULL);
    CGLDestroyContext(ctx);
    return 1;
}

int main(void)
{
    printf("== cgl-probe ==\n");

    /* 1: the #21 failing case — accelerated 3.2 core (what GLFW/LWJGL request) */
    CGLPixelFormatAttribute accel32[] = {
        kCGLPFAAccelerated,
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_GL3_Core,
        (CGLPixelFormatAttribute)0 };
    int have_accel = try_format("accel-3.2", accel32);

    /* 2: accelerated legacy profile (old GLX/GL apps) */
    CGLPixelFormatAttribute accelLegacy[] = {
        kCGLPFAAccelerated,
        (CGLPixelFormatAttribute)0 };
    int have_accel_legacy = try_format("accel-legacy", accelLegacy);

    /* 3: software baseline — must always work */
    CGLPixelFormatAttribute soft32[] = {
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_GL3_Core,
        (CGLPixelFormatAttribute)0 };
    int have_soft = try_format("soft-3.2", soft32);

    printf("== summary: accelerated=%s legacy-accelerated=%s software=%s ==\n",
           have_accel ? "YES" : "no", have_accel_legacy ? "YES" : "no",
           have_soft ? "YES" : "no");

    if (have_accel) return 0;
    if (have_soft || have_accel_legacy) return 1;
    return 2;
}
