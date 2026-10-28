import Toybox.Lang;

class Theme {
    enum Kind {
        LIGHT,
        DARK,
        SLEEP
    }

    var top as Number;
    var bottom as Number;
    var border as Number;
    var stackNear as Number;
    var stackFar as Number;
    var hinge as Number;
    var tab as Number;
    var tabEdge as Number;
    var digit as Number;

    // SLEEP is the dark tile dimmed to stay under the AMOLED always-on limit of 10% screen luminance
    function initialize(kind as Kind) {
        switch (kind) {
            case DARK:
                top = 0x545454;
                bottom = 0x2A2A2A;
                border = 0xABABAB;
                stackNear = 0x545454;
                stackFar = 0xABABAB;
                hinge = 0x161616;
                tab = 0x8C8C8C;
                tabEdge = 0x3C3C3C;
                digit = 0xFFFFFF;
                break;
            case SLEEP:
                top = 0x1E1E1E;
                bottom = 0x141414;
                border = 0x3A3A3A;
                stackNear = 0x1A1A1A;
                stackFar = 0x2C2C2C;
                hinge = 0x080808;
                tab = 0x3A3A3A;
                tabEdge = 0x222222;
                digit = 0xC8C8C8;
                break;
            default:
                top = 0xFFFFFF;
                bottom = 0xD5D5D5;
                border = 0x545454;
                stackNear = 0xABABAB;
                stackFar = 0x545454;
                hinge = 0x545454;
                tab = 0xBDBDBD;
                tabEdge = 0x6E6E6E;
                digit = 0x000000;
        }
    }
}
