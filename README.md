# Kinvey GeoTag
This is a Kinvey sample app, to location-based search, 3rd-Party location services, Push notifications, and Business Logic with Collection Hooks and Custom Endpoints. 

In particular in addition to showing location-based data, this app allows user actions to trigger push notifications to other users that are near new notes and are interested in certain tags. 
![](https://github.com/KinveyApps/GeoTag-iOS/raw/master/Screenshots/GeoTag_ss1.png)
![](https://github.com/KinveyApps/GeoTag-iOS/raw/master/Screenshots/GeoTag_ss2.png)

For more details about location, see the blog post at http://goo.gl/9dyMm.
For more details about business logic, see http://devcenter.kinvey.com/ios/guides/business-logic.

## Using the App
The app shows a map highlighting the user's current location. The map is annotated with nearby hotels (from the 3rd-paty location service) as well as yours and other user's notes that match your selected tags. 

Tap the "Tags" button to see a list of nearby tags. Selecting a tag will cause the user to subscribe to be notified for new notes with that tag as well as display those notes on the map. 

To enter a new note, type in the text field. Any word preceded by a `#` will be added as a tag. 

## Set-up

### Set up the App in Xcode

Also, you have to update `app-key` and `app-secret` in the file `KGAAppDelegate.m` to your app-key and app-secret from the Kinvey console. 

To enable push, you need a push certificate from the Apple developer portal. Upload to Kinvey (under the push configuration) and enter the `Push Key` and `Push Secret` in the file `KGAAppDelegate.m. 

### Set up Locations services

To enable Data Integration with this app, just

* Go to the **New Collection** (Data `+` button), press `New Data Link` and select a provider. For example, choose "FourSquare" ![Enable Data Integration](https://github.com/KinveyApps/GeoTag-iOS/raw/master/Screenshots/Enable.png "Enable Data Integration")
* Name the data link name `hotels` and enter your foursquare credentials. Then press `Add Data Link`. ![Enter Credentials](https://github.com/KinveyApps/GeoTag-iOS/raw/master/Screenshots/Active.png "Enter Credentials")

### Set up Collection Hook To Automatically Push to Nearby users
1. From the `Data` -> `New Collection` menu, add a new collection and call it `mapNotes`.
2. From the `Business Logic` -> `Collection Hooks` menu, select the `mapNotes` collection in the left menu. 
3. Select __`After` every `Save` run this function__ from the javascript area.
4. Enter the code from [`after_save_mapnotes.js`](https://github.com/KinveyApps/GeoTag-iOS/raw/master/after_save_mapnotes.js) in the code window:

```
function onPostSave(request, response, modules){
  var push = modules.push, collectionAccess = modules.collectionAccess, logger = modules.logger;
  var userCollection = collectionAccess.collection('user');
  var body = request.body;
  if (body.tags && body._geoloc) {
    logger.info("added map note with tags: " + body.tags +", location: "+ body._geoloc);
    var distanceInMiles = 5.0 /*5 mi radius*/ / 3963.192;
    var query = {"tags": {"$in":body.tags}, "_geoloc":{"$nearSphere": body._geoloc,"$maxDistance":distanceInMiles}};
    userCollection.find(query, function (err, userColl) {
      logger.info("got " + userColl.length + " users with matching tags.");
      if (err) {
        logger.error('Query failed: '+ err);
      } else {
        userColl.forEach(function (user) {
          logger.info('Pushing message to ' + user.username);
          push.send(user, "New notes for tag(s): " + body.tags);
        });
      }
      response.continue();
    });
 } else {
   logger.info("no tags in " + body);
   response.continue();
 }
}
```

This code does the following:

1. Extracts any tags and location from the just saved `MapNote` object. 
2. Searches the user collection for users that are (a) last within 5 miles of the note, and (b) have subscribed at least of the new note's tags in it's `tags` field.
3. For each of the users that satisfy these requirements, send a push notification letting them know a new note is available for those tags.
4. __Next Step:__ An even better form of the push notification would be include the note's `_id` and just reload that note. Right now the app just displays an alert and reloads all the notes. 


### Set up Custom Endpoint
1. From the `Business Logic` -> `Endpoints` menu, create a new endpoint called `tagsNearMe`.
2. Enter the code from [`tagsNearMe.js`](https://github.com/KinveyApps/GeoTag-iOS/raw/master/tagsNearMe.js) in the code window:

```
function getTags(request,response,modules,user) {
  var headers = {"Authorization":request.headers.authorization}; //re-use the current user's ACLs rather than master secret
  var loc = user._geoloc;
  var qs = '{"_geoloc":{"$nearSphere":['+loc+'],"$maxDistance":"10"}}'; //find notes within 10 miles
  var uri = 'https://' + request.headers.host + '/appdata/'+request.appKey+'/mapNotes/?query='+qs; //build the request
  modules.request.get({uri: uri, headers: headers}, function(error, res, body){
	if (error){
	  modules.logger.error(error);
	  response.body = {error: error.message};
      response.complete(res.status);
	} else {
	  //iterate through all the notes and count the tags
	  var elements = JSON.parse(body);
	  var tags = {};
	  elements.forEach(function(doc){
		doc.tags.forEach(function(tagar) {
		  if (tags[tagar]) {
			tags[tagar]++;
		  } else {
			tags[tagar] = 1;
		  }
		});
	  });
	  response.body = tags; //return all the tags with their count, could create a count threshold in the future
	  response.complete(200);
	}
});
}

function onRequest(request, response, modules){
  var collectionAccess = modules.collectionAccess;
  //find the current user in the user collection
  collectionAccess.collection('user').find({"username": request.username}, function (err, userColl) {
     if (err) {
         response.body = {error: error.message};
         response.complete(434);
     } else {
         getTags(request,response,modules,userColl[0]);
     }
  });
}
``` 

This code does the following:

1. The `onRequest` method is called when the request comes in. 
2. This method looks up the user using `collectionAccess`. The user object is needed to obtain the user's location.
3. In `getTags()` a call is made "as the user" using the user's `Authorization` header to `mapNotes` collection. This is done in order to respect the user's ACLs (as collectionAccess is done as the "master secret"). For GeoTag, this should not make a difference since `mapNotes` is globally readable by default.
4. If the response is successful, it will be an array of `MapNotes` objects. This array is iterated over and the each of the tags is counted in a running total.
5. After all the notes are counted, the totals object is returned to the app.  
6. __Next Step:__ A good next step is to limit the tags to the 20 most popular, or only display tags that have been used 5 or more times in order to limit the noisiness of the data. 

__NOTE:__ it is important to `complete()` the response in all terminal branches, or the client will timeout waiting for a response. 

####Client usage
```
[KCSCustomEndpoints callEndpoint:@"tagsNearMe" params:nil completionBlock:^(id results, NSError *error) {
    if (results) {
        //TODO: custom logics
    } else {
        //TODO: handle error
    }
}];
```

## System Requirements
* Xcode 4.5+
* iPad/iPhone/iPod Touch
* iOS 6+
* KinveyKit 1.17.0+

## Contact
Website: [www.kinvey.com](http://www.kinvey.com)

Support: [support@kinvey.com](http://docs.kinvey.com/mailto:support@kinvey.com)

## License

Copyright (c) 2014 Kinvey, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.