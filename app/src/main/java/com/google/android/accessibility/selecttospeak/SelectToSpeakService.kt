package com.google.android.accessibility.selecttospeak

import com.jev.probe.capture.ChatCaptureService

/**
 * Accessibility entry point for [ChatCaptureService]. Registered under this
 * class name in AndroidManifest — do not rename the class or the Manifest
 * entry. All capture logic lives in [ChatCaptureService].
 */
class SelectToSpeakService : ChatCaptureService()
