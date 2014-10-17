package io.trigger.forge.android.modules.facebook;

import io.trigger.forge.android.core.ForgeApp;
import io.trigger.forge.android.core.ForgeLog;
import io.trigger.forge.android.core.ForgeTask;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.apache.http.NameValuePair;
import org.apache.http.client.HttpClient;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicNameValuePair;

import android.content.SharedPreferences;

import com.facebook.FacebookDialogException;
import com.facebook.FacebookOperationCanceledException;
import com.facebook.FacebookRequestError;
import com.facebook.FacebookServiceException;
import com.facebook.android.AsyncFacebookRunner;
import com.facebook.android.Facebook;
import com.google.gson.JsonObject;

public class Util {
	
	protected static Facebook facebook = null;
	private static AsyncFacebookRunner runner = null;
	private static boolean partnerProgramNotified = false;

	public static void partnerProgram(ForgeTask task) {
		if (!partnerProgramNotified) {
			task.performAsync(new Runnable() {
				
				@Override
				public void run() {
					// Create a new HttpClient and Post Header
				    HttpClient httpclient = new DefaultHttpClient();
				    HttpPost httppost = new HttpPost("https://www.facebook.com/impression.php");

				    try {
				        // Add your data
				        List<NameValuePair> nameValuePairs = new ArrayList<NameValuePair>(2);
				        nameValuePairs.add(new BasicNameValuePair("plugin", "featured_resources"));
				        JsonObject payload = new JsonObject();
				        payload.addProperty("resource", "triggerio_triggerio");
				        payload.addProperty("appid", ForgeApp.configForPlugin("facebook").get("appid").getAsString());
				        if (!ForgeApp.appConfig.has("platform_version")) {
				        	return;
				        }
			        	payload.addProperty("version", ForgeApp.appConfig.get("platform_version").getAsString());
				        nameValuePairs.add(new BasicNameValuePair("payload", payload.toString()));
				        httppost.setEntity(new UrlEncodedFormEntity(nameValuePairs));

				        // Execute HTTP Post Request
				        httpclient.execute(httppost);
				    } catch (Exception e) {
				        ForgeLog.w("Error reporting partner data to Facebook");
				    }
				}
			});
			
			partnerProgramNotified = true;
		}
	}
	
	public static Facebook getFacebook(ForgeTask task) {
		if (facebook == null) {
			facebook = new Facebook(ForgeApp.configForPlugin("facebook").get("appid").getAsString());
		}
		return facebook;
	}

	public static AsyncFacebookRunner getFacebookRunner(ForgeTask task) {
		if (runner == null) {
			runner = new AsyncFacebookRunner(getFacebook(task));
		}
		return runner;
	}
	
	public static SharedPreferences getStorage(ForgeTask task) {
 		return ForgeApp.getActivity().getSharedPreferences("facebook", 0);
 	}
	

	private static ArrayList<String> _publishPermissions;
	private static ArrayList<String> publishPermissions() {
		if (_publishPermissions == null) {
			// From: https://developers.facebook.com/docs/facebook-login/permissions/v2.0#reference
			String[] permissions = {"ads_management", "create_event", "rsvp_event", "manage_friendlists", "manage_notifications", "manage_pages", "publish_actions"};
			_publishPermissions = new ArrayList<String>(Arrays.asList(permissions));
		}
		return _publishPermissions;
	}
	
	public static List<String> readPermissionsInPermissions(List<String> permissions) {
		List<String> subset = new ArrayList<String>();
		subset.addAll(permissions);
		subset.removeAll(publishPermissions());
		return subset;
	}

	public static List<String> publishPermissionsInPermissions(List<String> permissions) {
		List<String> subset = new ArrayList<String>();
		subset.addAll(permissions);
		subset.retainAll(publishPermissions());
		return subset;
	}
	
	public static boolean grantedPermissionsAreSuperset(List<String> grantedPermissions, List<String> requestedPermissions) {
		List<String> superset = new ArrayList<String>();
		superset.addAll(requestedPermissions);
		superset.removeAll(grantedPermissions);
		return superset.isEmpty();
	}
}
