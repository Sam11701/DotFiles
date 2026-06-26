import QtQuick
import QtQuick.Layouts

Rectangle {
    default property alias content: row.data
    property real uiScale: 1.0

    radius: height / 2
    color: Colors.surface
    opacity: 0.82
    implicitHeight: 21 * uiScale
    implicitWidth: row.implicitWidth + 18 * uiScale

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4 * uiScale
    }
}
