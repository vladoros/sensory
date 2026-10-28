import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The watch face's own settings on the watch, for builds that Garmin Connect cannot configure, such as sideloaded ones
class SettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => Rez.Strings.AppName});
        var ids = SettingsTable.ids();
        var kinds = SettingsTable.kinds();
        var titles = SettingsTable.titles();
        for (var i = 0; i < ids.size(); i++) {
            var value = Application.Properties.getValue(ids[i]);
            if (kinds[i] == SettingsTable.BOOLEAN) {
                addItem(new WatchUi.ToggleMenuItem(titles[i], null, i, value == true, null));
            } else if (kinds[i] == SettingsTable.LIST) {
                addItem(new WatchUi.MenuItem(titles[i], optionLabel(i, value), i, null));
            } else {
                addItem(new WatchUi.MenuItem(titles[i], value instanceof String ? value : "", i, null));
            }
        }
    }

    static function optionLabel(i as Number, value) as ResourceId? {
        var values = SettingsTable.values(i);
        for (var k = 0; k < values.size(); k++) {
            if (values[k] == value) {
                return SettingsTable.labels(i)[k];
            }
        }
        return null;
    }
}

function applySettings() as Void {
    (Application.getApp() as SensoryApp).onSettingsChanged();
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var i = item.getId() as Number;
        var id = SettingsTable.ids()[i];
        var kind = SettingsTable.kinds()[i];
        if (kind == SettingsTable.BOOLEAN) {
            Application.Properties.setValue(id, (item as WatchUi.ToggleMenuItem).isEnabled());
            applySettings();
        } else if (kind == SettingsTable.LIST) {
            WatchUi.pushView(new OptionsMenu(i), new OptionsDelegate(i, item), WatchUi.SLIDE_LEFT);
        } else {
            var current = Application.Properties.getValue(id);
            WatchUi.pushView(new WatchUi.TextPicker(current instanceof String ? current : ""),
                new TextDelegate(id, item), WatchUi.SLIDE_LEFT);
        }
    }
}

class OptionsMenu extends WatchUi.Menu2 {
    function initialize(i as Number) {
        Menu2.initialize({:title => SettingsTable.titles()[i]});
        var labels = SettingsTable.labels(i);
        var values = SettingsTable.values(i);
        for (var k = 0; k < values.size(); k++) {
            addItem(new WatchUi.MenuItem(labels[k], null, values[k], null));
        }
        var current = Application.Properties.getValue(SettingsTable.ids()[i]);
        for (var k = 0; k < values.size(); k++) {
            if (values[k] == current) {
                setFocus(k);
            }
        }
    }
}

class OptionsDelegate extends WatchUi.Menu2InputDelegate {
    private var _index as Number;
    private var _parent as WatchUi.MenuItem;

    function initialize(i as Number, parent as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _index = i;
        _parent = parent;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId();
        Application.Properties.setValue(SettingsTable.ids()[_index], value as Number);
        _parent.setSubLabel(SettingsMenu.optionLabel(_index, value));
        applySettings();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class TextDelegate extends WatchUi.TextPickerDelegate {
    private var _id as String;
    private var _parent as WatchUi.MenuItem;

    function initialize(id as String, parent as WatchUi.MenuItem) {
        TextPickerDelegate.initialize();
        _id = id;
        _parent = parent;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        Application.Properties.setValue(_id, text);
        _parent.setSubLabel(text);
        applySettings();
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}
