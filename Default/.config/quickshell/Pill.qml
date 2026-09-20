import QtQuick
import QtQuick.Layouts

Rectangle {
    default property alias content: row.data
    property real uiScale: 1.0
    property bool pillMode: true

    radius: pillMode ? height / 2 : 4
    color: pillMode ? Colors.surface : "transparent"
    implicitHeight: 21 * uiScale
    implicitWidth: row.implicitWidth + 18 * uiScale
    antialiasing: true

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4 * uiScale
    }
}
