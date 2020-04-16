# TD3511-Siemens-
TD351x elektronischer Zähler

Der Stromzähler mit IR-Schnittstelle sendet nach einem "Anforderungtelegramm" Daten raus. Das Telegramm ist mit 300 Baud, 7 Bit, 1 Stoppbit  und gerader Parität zu senden. Das ist der Initialmodus von Geräten,  die das Protokoll IEC 62056-21 implementieren.

Der Zähler wird von 300 baud auf 19200 baud umgeschalten, damit die Übertragung schneller erfolgt.

Die Umschaltzeit ist kritisch und ich habe sie durch rumprobieren herausbekommen.

Das Modul wird zum Auslesen des TD3511 über den IR-Schreib-Lesekopf (USB-Interface) (https://wiki.volkszaehler.org/hardware/controllers/ir-schreib-lesekopf-usb-ausgang) von Volkszähler genutzt.

Die Daten werden in eine MySQL-DB von FHEM geschrieben und sind somit dort auswertbar.

<img src="/Diagramm_TD3511.JPG" alt="Diagramm FHEM"/>
