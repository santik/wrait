package com.wrait.app.test.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStoreFile
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.wrait.app.data.repository.PreferencesRepositoryImpl
import com.wrait.app.di.DataStoreBindsModule
import com.wrait.app.di.DataStoreModule
import com.wrait.app.domain.repository.PreferencesRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import javax.inject.Singleton

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [DataStoreModule::class, DataStoreBindsModule::class]
)
object TestDataStoreModule {

    @Provides
    @Singleton
    fun provideDataStore(@ApplicationContext context: Context): DataStore<Preferences> =
        // Unique filename per component instantiation prevents state leakage across test methods.
        // With HiltAndroidRule the Hilt component is recreated per test method, so nanoTime()
        // here gives a fresh DataStore file for each test.
        // The CoroutineScope is not tied to the test lifecycle, but this is safe: Hilt recreates
        // the SingletonComponent (and therefore this DataStore instance) for every test method,
        // so each test gets its own scope + file. The orphaned scope from the previous test is
        // kept alive only until the process exits, which happens at most at the end of the test
        // run — no cross-test interference is possible.
        PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
            produceFile = {
                context.preferencesDataStoreFile("test_prefs_${System.nanoTime()}")
            }
        )

    @Provides
    @Singleton
    fun providePreferencesRepository(
        dataStore: DataStore<Preferences>
    ): PreferencesRepository = PreferencesRepositoryImpl(dataStore)
}
