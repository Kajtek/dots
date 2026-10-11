#!/usr/bin/env python3
"""Standalone StatusNotifierWatcher, so tray icons survive waybar restarts.

Tray apps register their icon with whoever owns org.kde.StatusNotifierWatcher on the session
bus, and waybar's tray module owns that name itself. When the bar restarts (the hotplug handler
in hyprland.lua, or a crash) the registrations die with it. libappindicator apps (blueman,
Steam) notice and register again; Electron apps such as Signal register once at startup and
never do, so their icon is gone for good. This process owns the name instead, outlives every
bar, and waybar's tray just reads the list from it.

hyprland.lua starts it before the bars. It never queues for the name: if something already owns
it, or it loses it, it exits non-zero. waybar asks for the name too and waits in line, so if this
watcher dies waybar takes over and the tray keeps working, only without the restart protection.

Implements the freedesktop StatusNotifierItem watcher interface (the KDE names are the ones apps
and waybar actually use). Items are stored as "<bus name><object path>", as waybar expects.
"""

import sys

from gi.repository import Gio, GLib

NAME = "org.kde.StatusNotifierWatcher"
PATH = "/StatusNotifierWatcher"
INTERFACE = Gio.DBusNodeInfo.new_for_xml("""
<node>
  <interface name="org.kde.StatusNotifierWatcher">
    <method name="RegisterStatusNotifierItem"><arg type="s" direction="in"/></method>
    <method name="RegisterStatusNotifierHost"><arg type="s" direction="in"/></method>
    <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
    <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
    <property name="ProtocolVersion" type="i" access="read"/>
    <signal name="StatusNotifierItemRegistered"><arg type="s"/></signal>
    <signal name="StatusNotifierItemUnregistered"><arg type="s"/></signal>
    <signal name="StatusNotifierHostRegistered"/>
    <signal name="StatusNotifierHostUnregistered"/>
  </interface>
</node>
""").interfaces[0]

items = {}  # "<bus name><path>" -> bus name watch id
hosts = {}  # host bus name -> bus name watch id


def on_call(conn, sender, path, interface, method, params, invocation):
    (service,) = params.unpack()
    if method == "RegisterStatusNotifierItem":
        # Apps pass either their bus name (the item then lives at the default path) or just an
        # object path (the item lives on the caller's own connection).
        if service.startswith("/"):
            bus, item_path = sender, service
        else:
            bus, item_path = service, "/StatusNotifierItem"
        item = bus + item_path
        if item not in items:
            items[item] = Gio.bus_watch_name_on_connection(
                conn, bus, Gio.BusNameWatcherFlags.NONE, None,
                lambda c, _name: forget_item(c, item))
            emit(conn, "StatusNotifierItemRegistered", GLib.Variant("(s)", (item,)))
    else:
        if service not in hosts:
            hosts[service] = Gio.bus_watch_name_on_connection(
                conn, service, Gio.BusNameWatcherFlags.NONE, None, forget_host)
            emit(conn, "StatusNotifierHostRegistered", None)
    invocation.return_value(None)


def forget_item(conn, item):
    Gio.bus_unwatch_name(items.pop(item))
    emit(conn, "StatusNotifierItemUnregistered", GLib.Variant("(s)", (item,)))


def forget_host(conn, name):
    Gio.bus_unwatch_name(hosts.pop(name))
    emit(conn, "StatusNotifierHostUnregistered", None)


def on_get_property(conn, sender, path, interface, prop):
    if prop == "RegisteredStatusNotifierItems":
        return GLib.Variant("as", list(items))
    if prop == "IsStatusNotifierHostRegistered":
        return GLib.Variant("b", bool(hosts))
    return GLib.Variant("i", 0)


def emit(conn, signal, params):
    conn.emit_signal(None, PATH, NAME, signal, params)


def on_bus_acquired(conn, _name):
    conn.register_object_with_closures2(PATH, INTERFACE, on_call, on_get_property, None)


def on_name_lost(_conn, _name):
    print(f"sni-watcher: {NAME} is owned by another process or was lost; exiting",
          file=sys.stderr)
    loop.quit()


loop = GLib.MainLoop()
Gio.bus_own_name(Gio.BusType.SESSION, NAME, Gio.BusNameOwnerFlags.DO_NOT_QUEUE,
                 on_bus_acquired, None, on_name_lost)
loop.run()
sys.exit(1)  # the loop only stops when the name is lost
