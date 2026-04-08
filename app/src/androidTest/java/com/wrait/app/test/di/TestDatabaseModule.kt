package com.wrait.app.test.di

import android.content.Context
import androidx.room.Room
import com.wrait.app.data.EntryDao
import com.wrait.app.data.WraitDatabase
import com.wrait.app.di.DatabaseModule
import dagger.Module
import dagger.Provides
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import javax.inject.Singleton

@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [DatabaseModule::class]
)
object TestDatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): WraitDatabase =
        Room.inMemoryDatabaseBuilder(context, WraitDatabase::class.java)
            .allowMainThreadQueries()
            .build()

    @Provides
    fun provideEntryDao(db: WraitDatabase): EntryDao = db.entryDao()
}
