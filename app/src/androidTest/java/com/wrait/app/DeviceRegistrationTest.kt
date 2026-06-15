package com.wrait.app

import androidx.lifecycle.viewModelScope
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.wrait.app.data.EntryDao
import com.wrait.app.data.WraitDatabase
import com.wrait.app.data.api.RegistrationResult
import com.wrait.app.data.device.NetworkAvailability
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.domain.usecase.CleanupTranscriptUseCase
import com.wrait.app.data.repository.EntryRepositoryImpl
import com.wrait.app.domain.model.PrivacyMode
import com.wrait.app.domain.usecase.RegisterDeviceUseCase
import com.wrait.app.domain.repository.EntryRepository
import com.wrait.app.test.fake.FakeAnalyticsTracker
import com.wrait.app.test.fake.FakeDeviceRegistrationService
import com.wrait.app.test.fake.FakeDevModeProvider
import com.wrait.app.test.fake.FakeEntriesExportService
import com.wrait.app.test.fake.FakeTranscriptCleanupService
import com.wrait.app.test.fake.FakePreferencesRepository
import com.wrait.app.test.fake.FakeNetworkAvailability
import com.wrait.app.test.fake.FakeTranscriptionService
import com.wrait.app.test.util.FakeTimeProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Ignore
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DeviceRegistrationTest {

    private val testDispatcher = UnconfinedTestDispatcher()
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    private lateinit var db: WraitDatabase
    private lateinit var entryDao: EntryDao
    private lateinit var entryRepository: EntryRepository
    private lateinit var fakeNetworkAvailability: FakeNetworkAvailability
    private val createdVms = mutableListOf<MainViewModel>()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        db = Room.inMemoryDatabaseBuilder(context, WraitDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        entryDao = db.entryDao()
        entryRepository = EntryRepositoryImpl(entryDao, FakeTimeProvider())
        fakeNetworkAvailability = FakeNetworkAvailability()
    }

    @After
    fun tearDown() {
        createdVms.forEach { it.viewModelScope.cancel() }
        createdVms.clear()
        Dispatchers.resetMain()
        db.close()
    }

    private fun createViewModel(
        fakePrefs: FakePreferencesRepository = FakePreferencesRepository(),
        fakeRegistration: FakeDeviceRegistrationService = FakeDeviceRegistrationService(),
        networkAvailability: NetworkAvailability = fakeNetworkAvailability,
    ): Pair<MainViewModel, FakeDeviceRegistrationService> {
        val deviceIdProvider = DeviceIdProvider(context)
        val vm = MainViewModel(
            preferencesRepository = fakePrefs,
            entryRepository = entryRepository,
            transcriptionService = FakeTranscriptionService(),
            networkAvailability = networkAvailability,
            cleanupTranscriptUseCase = CleanupTranscriptUseCase(
                transcriptCleanupService = FakeTranscriptCleanupService(),
            ),
            registerDeviceUseCase = RegisterDeviceUseCase(
                preferencesRepository = fakePrefs,
                deviceIdProvider = deviceIdProvider,
                registrationService = fakeRegistration,
                ioDispatcher = testDispatcher,
            ),
            entriesExportService = FakeEntriesExportService(),
            devModeProvider = FakeDevModeProvider(),
            analyticsTracker = FakeAnalyticsTracker(),
            ioDispatcher = testDispatcher,
        ).also { createdVms.add(it) }
        return vm to fakeRegistration
    }

    // ── call gating ──────────────────────────────────────────────────────────

    @Test
    fun firstLaunch_registrationCalled() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialDeviceRegistered = false)
        val (vm, reg) = createViewModel(fakePrefs = fakePrefs)

        vm.initJob.join()

        assertEquals(1, reg.callCount)
    }

    @Test
    fun firstLaunch_deviceIdIs64CharHex() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialDeviceRegistered = false)
        val (vm, reg) = createViewModel(fakePrefs = fakePrefs)

        vm.initJob.join()

        assertNotNull(reg.lastDeviceId)
        assertTrue(
            "Device ID must be 64 lowercase hex chars",
            reg.lastDeviceId!!.matches(Regex("^[0-9a-f]{64}$"))
        )
    }

    @Test
    fun alreadyRegistered_registrationSkipped() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialDeviceRegistered = true)
        val (vm, reg) = createViewModel(fakePrefs = fakePrefs)

        vm.initJob.join()

        assertEquals(0, reg.callCount)
    }

    // ── flag persistence ──────────────────────────────────────────────────────

    @Test
    @Ignore
    fun registrationSuccess_setsFlagTrue() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialDeviceRegistered = false)
        val fakeReg = FakeDeviceRegistrationService().apply {
            result = RegistrationResult.Success()
        }
        val (vm, _) = createViewModel(fakePrefs = fakePrefs, fakeRegistration = fakeReg)

        vm.initJob.join()

        assertTrue(fakePrefs.deviceRegistered.first())
    }

    @Test
    fun registrationFailure_flagRemainsFlase() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialDeviceRegistered = false)
        val fakeReg = FakeDeviceRegistrationService().apply {
            result = RegistrationResult.Failure("network error")
        }
        val (vm, _) = createViewModel(fakePrefs = fakePrefs, fakeRegistration = fakeReg)

        vm.initJob.join()

        assertFalse(fakePrefs.deviceRegistered.first())
    }

    // ── resilience ────────────────────────────────────────────────────────────

    @Test
    fun registrationException_initJobCompletes() = runTest(testDispatcher) {
        val fakePrefs = FakePreferencesRepository(initialDeviceRegistered = false)
        val fakeReg = FakeDeviceRegistrationService().apply { shouldThrow = true }
        val (vm, _) = createViewModel(fakePrefs = fakePrefs, fakeRegistration = fakeReg)

        vm.initJob.join()

        // initJob completes normally — later init steps (privacyMode seed) ran
        val mode = fakePrefs.privacyMode.first()
        assertTrue(mode == PrivacyMode.MODE_BEST || mode == PrivacyMode.MODE_OFFLINE)
    }
}
