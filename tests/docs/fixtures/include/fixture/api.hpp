/** @file
 *  @brief Fixture public API.
 */
/** @defgroup fixture_reference Fixture reference
 *  @brief Layout brief fixture.
 *
 *  Layout detailed fixture.
 */
/** @brief Fixture namespace. */
namespace fixture {
/** @brief Return the fixture value.
 *  @ingroup fixture_reference
 */
inline int value() { return 42; }
/** @brief Internal API omitted from the extended documentation. */
struct hidden {};
/** @brief Internal API omitted through an additive Doxygen option. */
struct extra {};
}
