/** @file
 *  @brief Fixture public API.
 */
/** @brief Fixture namespace. */
namespace fixture {
/** @brief Return the fixture value. */
inline int value() { return 42; }
/** @brief Internal API omitted from the extended documentation. */
struct hidden {};
/** @brief Internal API omitted through an additive Doxygen option. */
struct extra {};
}
