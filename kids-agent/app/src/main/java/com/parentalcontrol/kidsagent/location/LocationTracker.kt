package com.parentalcontrol.kidsagent.location

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.*
import com.parentalcontrol.kidsagent.data.db.AppDatabase
import com.parentalcontrol.kidsagent.data.db.OfflineLocationEntity
import com.parentalcontrol.kidsagent.data.model.LocationPayload
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class LocationTracker(
    private val context: Context,
    private val onLocationUpdated: (LocationPayload) -> Unit
) {
    companion object {
        private const val TAG = "LocationTracker"
        private const val UPDATE_INTERVAL_MS = 15_000L // 15 seconds
        private const val FASTEST_INTERVAL_MS = 5_000L
        private const val MIN_DISTANCE_METERS = 5f     // 5 meters
    }

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    private val db = AppDatabase.getInstance(context)
    private val scope = CoroutineScope(Dispatchers.IO)

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            handleNewLocation(location)
        }
    }

    private var isTracking = false

    @SuppressLint("MissingPermission")
    fun startTracking() {
        if (isTracking) return

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            UPDATE_INTERVAL_MS
        ).apply {
            setMinUpdateIntervalMillis(FASTEST_INTERVAL_MS)
            setMinUpdateDistanceMeters(MIN_DISTANCE_METERS)
            setWaitForAccurateLocation(false)
        }.build()

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
            isTracking = true
            Log.d(TAG, "Location tracking started")

            // Also request last known location immediately via FusedClient
            fusedLocationClient.lastLocation.addOnSuccessListener { loc ->
                if (loc != null) handleNewLocation(loc)
            }

            // Fallback to standard LocationManager for immediate coordinate
            val lm = context.getSystemService(Context.LOCATION_SERVICE) as? android.location.LocationManager
            val gpsLoc = lm?.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
            val netLoc = lm?.getLastKnownLocation(android.location.LocationManager.NETWORK_PROVIDER)
            val bestLoc = when {
                gpsLoc != null && netLoc != null -> if (gpsLoc.time >= netLoc.time) gpsLoc else netLoc
                gpsLoc != null -> gpsLoc
                else -> netLoc
            }
            if (bestLoc != null) {
                handleNewLocation(bestLoc)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException starting location updates: ${e.message}")
        }
    }

    fun stopTracking() {
        if (!isTracking) return
        fusedLocationClient.removeLocationUpdates(locationCallback)
        isTracking = false
        Log.d(TAG, "Location tracking stopped")
    }

    private fun handleNewLocation(location: Location) {
        val payload = LocationPayload(
            latitude = location.latitude,
            longitude = location.longitude,
            accuracy = location.accuracy,
            altitude = location.altitude,
            speed = location.speed,
            bearing = location.bearing,
            timestamp = if (location.time > 0) location.time else System.currentTimeMillis()
        )

        // Cache coordinate locally in Room offline DB immediately
        scope.launch {
            try {
                val entity = OfflineLocationEntity.fromPayload(payload, isSynced = false)
                db.locationDao().insertLocation(entity)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cache offline location: ${e.message}")
            }
        }

        onLocationUpdated(payload)
    }
}

