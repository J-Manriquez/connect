package com.andodevs.connectremote

import java.util.UUID

/**
 * UUID RFCOMM dedicado al control remoto. Distinto del UUID SPP
 * (00001101-...) que usa el puente de notificaciones/media de `connect`,
 * para no interferir con ese canal existente.
 */
object RemoteProtocol {
    val SERVICE_UUID: UUID = UUID.fromString("d8d76f9c-c583-4a45-91eb-ef72a3704ad5")
    const val SERVICE_NAME = "ConnectRemoteControl"

    const val MODE_CURSOR = "cursor"
    const val MODE_DPAD = "dpad"
}
