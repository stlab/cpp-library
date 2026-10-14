#ifndef NESTED_CONTEXT
#error Missing nested context
#endif
#ifdef PUBLIC_CONTEXT
#error Downstream requirements leaked into dependency
#endif
namespace nested { struct value {}; }
