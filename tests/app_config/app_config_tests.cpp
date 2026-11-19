#include <catch_main.hpp>

#include "libslic3r/AppConfig.hpp"

using namespace Slic3r;

TEST_CASE("Home page online content is opt-in by default", "[AppConfig]")
{
    AppConfig config;

    for (const char *key : { "show_library", "staff_pick_switch", "show_print_history", "show_makerlab", "show_maker_supply" }) {
        INFO("key: " << key);
        CHECK(config.get(key) == "false");
        CHECK_FALSE(config.get_bool(key));
    }
}


TEST_CASE("Home page opt-in keeps a stored choice", "[AppConfig]")
{
    AppConfig config;
    config.set_bool("show_makerlab", true);
    config.set_bool("show_maker_supply", true);
    config.set_bool("show_library", true);
    config.set_defaults();

    CHECK(config.get_bool("show_makerlab"));
    CHECK(config.get_bool("show_maker_supply"));
    CHECK(config.get_bool("show_library"));
}
