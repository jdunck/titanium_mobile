/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

package org.appcelerator.titanium.module;

import java.lang.ref.SoftReference;

import org.appcelerator.titanium.TitaniumActivity;
import org.appcelerator.titanium.TitaniumModuleManager;
import org.appcelerator.titanium.TitaniumWebView;
import org.appcelerator.titanium.api.ITitaniumModule;
import org.json.JSONObject;

import android.content.Context;
import android.os.Handler;
import android.webkit.WebView;

public abstract class TitaniumBaseModule implements ITitaniumModule
{
	//private static final String LCAT = "TiBaseModule";
	//private static final boolean DBG = TitaniumConfig.LOGD;

	private TitaniumModuleManager manager;
	private String moduleName;

	private SoftReference<TitaniumActivity> softActivity;
	private SoftReference<TitaniumWebView> softWebView;
	protected Handler handler;

	protected TitaniumBaseModule(TitaniumModuleManager manager, String moduleName)
	{
		manager.checkThread();

		this.manager = manager;
		this.moduleName = moduleName;
		this.handler = new Handler();

		// Cache references to other objects.
		TitaniumActivity activity = manager.getActivity();

		if (activity != null) {
			this.softActivity = new SoftReference<TitaniumActivity>(activity);
			this.softWebView = new SoftReference<TitaniumWebView>(activity.getWebView());
		} else {
			throw new IllegalStateException("Unable to get references to required objects.");
		}

		manager.addModule(this);
	}

	public TitaniumModuleManager getModuleManager() {
		return manager;
	}

	public TitaniumActivity getActivity() {
		return softActivity.get();
	}

	public TitaniumWebView getWebView() {
		return softWebView.get();
	}

	public Context getContext()
	{
		Context context = null;
		TitaniumActivity activity = softActivity.get();
		if (activity != null) {
			context = activity;
		}
		return context;
	}

	public abstract void register(WebView webView);

	/**
	 * evaluate Javascript in the context of the webview
	 */
	protected void evalJS(String js, final JSONObject data)
	{
		TitaniumWebView webView = softWebView.get();
		if (webView != null) {
			webView.evalJS(js, data);
		}
	}

	/**
	 * Name used during error reporting and in Javascript reference
	 */
	public String getModuleName() {
		return moduleName;
	}

	/**
	 * Forwarded from activities to allow module to be device friendly.
	 */
	public void onPause() {

	}

	/**
	 * Forwarded from activities to allow module to be device friendly.
	 */
	public void onResume() {

	}

	/**
	 * Forwarded from activities to allow module to be device friendly.
	 */
	public void onDestroy() {

	}

	protected void invokeUserCallback(String method, String data) {
		TitaniumWebView webView = softWebView.get();
		webView.evalJS(method, data);
	}

	protected String createJSONError(int code, String msg)
	{
		StringBuilder sb = new StringBuilder(256);
		sb.append("{ 'code' : ")
			.append(code)
			.append(" , 'message' : '")
			.append(msg)
			.append("' }")
			;
		return sb.toString();
	}
}
