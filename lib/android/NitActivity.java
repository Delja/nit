/* This file is part of NIT ( http://www.nitlanguage.org ).
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *	 http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package nit.app;

import android.app.Activity;
import android.os.Bundle;
import android.view.KeyEvent;

/*
 * Entry point to Nit applications on Android, redirect most calls to Nit
 */
public class NitActivity extends Activity {

	// Nit activity associated to `this`
	protected int nitActivity = 0;

	/*
	 * Calls to Nit or to the C framework
	 */

	static {
		System.loadLibrary("nit_app");
	}

	/*
	 * Callbacks to Nit through C
	 */
	protected native int nitRegisterActivity();
	protected native void nitOnCreate(int activity, Bundle savedInstanceState);
	protected native void nitOnStart(int activity);
	protected native void nitOnRestart(int activity);
	protected native void nitOnResume(int activity);
	protected native void nitOnPause(int activity);
	protected native void nitOnStop(int activity);
	protected native void nitOnDestroy(int activity);
	protected native void nitOnSaveInstanceState(int activity, Bundle savedInstanceState);
	protected native void nitOnRestoreInstanceState(int activity, Bundle savedInstanceState);
	protected native boolean nitOnBackPressed(int activity);
	protected native boolean nitOnKeyDown(int activity, int keyCode, KeyEvent event);
	protected native boolean nitOnKeyLongPress(int activity, int keyCode, KeyEvent event);
	protected native boolean nitOnKeyMultiple(int activity, int keyCode, int count, KeyEvent event);
	protected native boolean nitOnKeyUp(int activity, int keyCode, KeyEvent event);

	/*
	 * Implementation of OS callbacks
	 */

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		nitActivity = nitRegisterActivity();

		nitOnCreate(nitActivity, savedInstanceState);
	}

	@Override
	protected void onStart() {
		super.onStart();
		nitOnStart(nitActivity);
	}

	@Override
	protected void onRestart() {
		super.onRestart();
		nitOnRestart(nitActivity);
	}

	@Override
	protected void onResume() {
		super.onResume();
		nitOnResume(nitActivity);
	}

	@Override
	protected void onPause() {
		super.onPause();
		nitOnPause(nitActivity);
	}

	@Override
	protected void onStop() {
		super.onStop();
		nitOnStop(nitActivity);
	}

	@Override
	protected void onDestroy() {
		super.onDestroy();
		nitOnDestroy(nitActivity);
	}

	@Override
	public void onSaveInstanceState(Bundle savedInstanceState) {
		super.onSaveInstanceState(savedInstanceState);
		nitOnSaveInstanceState(nitActivity, savedInstanceState);
	}

	@Override
	public void onRestoreInstanceState(Bundle savedInstanceState) {
		super.onRestoreInstanceState(savedInstanceState);
		nitOnRestoreInstanceState(nitActivity, savedInstanceState);
	}

	@Override
	public void onBackPressed() {
		if (!nitOnBackPressed(nitActivity))
			super.onBackPressed();
	}

	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		return nitOnKeyDown(nitActivity, keyCode, event)
			|| super.onKeyDown(keyCode, event);
	}

	@Override
	public boolean onKeyLongPress(int keyCode, KeyEvent event) {
		return nitOnKeyLongPress(nitActivity, keyCode, event)
			|| super.onKeyLongPress(keyCode, event);
	}

	@Override
	public boolean onKeyMultiple(int keyCode, int count, KeyEvent event) {
		return nitOnKeyMultiple(nitActivity, keyCode, count, event)
			|| super.onKeyMultiple(keyCode, count, event);
	}

	@Override
	public boolean onKeyUp(int keyCode, KeyEvent event) {
		return nitOnKeyUp(nitActivity, keyCode, event)
			|| super.onKeyUp(keyCode, event);
	}
}
