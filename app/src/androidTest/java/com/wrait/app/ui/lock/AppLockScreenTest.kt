package com.wrait.app.ui.lock

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.wrait.app.MainActivity
import com.wrait.app.test.fake.FakeAppLockAuthenticatorFactory
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import javax.inject.Inject
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TestRule
import org.junit.runner.Description
import org.junit.runner.RunWith
import org.junit.runners.model.Statement

@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class AppLockScreenTest {
    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val behaviorRule: TestRule = object : TestRule {
        override fun apply(base: Statement, description: Description): Statement {
            return object : Statement() {
                override fun evaluate() {
                    FakeAppLockAuthenticatorFactory.setDefaultBehavior(
                        FakeAppLockAuthenticatorFactory.Behavior(
                            autoAuthenticate = false,
                        ),
                    )
                    try {
                        base.evaluate()
                    } finally {
                        FakeAppLockAuthenticatorFactory.resetDefaultBehavior()
                    }
                }
            }
        }
    }

    @get:Rule(order = 2)
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Inject
    lateinit var fakeAppLockAuthenticatorFactory: FakeAppLockAuthenticatorFactory

    @Before
    fun setUp() {
        hiltRule.inject()
    }

    @After
    fun tearDown() {
        fakeAppLockAuthenticatorFactory.reset()
    }

    @Test
    fun appStaysLockedUntilAuthenticationSucceeds() {
        composeRule.waitUntil(timeoutMillis = 5_000) {
            composeRule.onAllNodesWithTag("app_lock_overlay").fetchSemanticsNodes().isNotEmpty()
        }

        composeRule.onNodeWithTag("app_lock_overlay").assertIsDisplayed()

        fakeAppLockAuthenticatorFactory.succeedUnlock()

        composeRule.waitUntil(timeoutMillis = 5_000) {
            composeRule.onAllNodesWithContentDescription("Main action button")
                .fetchSemanticsNodes()
                .isNotEmpty()
        }

        composeRule.onNodeWithContentDescription("Main action button").assertIsDisplayed()
    }

    @Test
    fun unlockButtonAppearsAfterAuthenticationIsCancelled() {
        composeRule.waitUntil(timeoutMillis = 5_000) {
            composeRule.onAllNodesWithTag("app_lock_overlay").fetchSemanticsNodes().isNotEmpty()
        }

        fakeAppLockAuthenticatorFactory.cancelUnlock()

        composeRule.waitUntil(timeoutMillis = 5_000) {
            composeRule.onAllNodesWithTag("app_lock_unlock_main").fetchSemanticsNodes().isNotEmpty()
        }

        composeRule.onNodeWithTag("app_lock_unlock_main").assertIsDisplayed()
        composeRule.onNodeWithTag("app_lock_unlock_main").assertHasClickAction()
        composeRule.onNodeWithTag("app_lock_unlock_main").performClick()
    }
}
