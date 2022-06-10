## REST API notes:

1. To send a broadcast message to all processors in the signal chain, PUT to `/api/message`
   ```json
     {
       "text": "your message text here"
     }
   ```
   This is implemented in the `.sendMessage()` method of the oephys plugin.

   At present, the only processor that implements the handleBroadcastMessage() method is the Audio Monitor plugin. You could send it messages to select the channel you want to monitor, e.g.,
   ```json
     {
       "text": "AUDIO SELECT 10001 5"
     }
   ```
   or,
   ```matlab
     o.sendMessage('AUDIO SELECT 10001 5')
   ```
   to monitor channel 5.

   However, to do so you  need to know the stream id for the channel you want to monitor... 10001 in the example above. There currently seems to be no way to determine the relevent stream id, or even to get a list of all streams ids in the signal chain.

   To test the broadcast message above I had to attach a debugger to the running Open Ephys GUI process and interogate the dataStreamMap in the GenericProcessor class.

   Note: for the Audio Monitor processor, ther doesn't seem to be a way to select spike channels from the dropdown list that appears in it's UI. That dropdown seems to select among a defined set of channel selections, e.g., stereotrodes or tetrodes (?).

2. The API documentation suggests you can GET from `/api/streams` to get a
   list of streams, but this isn't implemented as far as I can see.

   I guess this is ok because if you're using the API you can set stream parameters for a processor directly...

3. To get info on a stream (e.g., it's parameters) for a specific 
   processor, GET from `/api/processors/<processor_id>/streams/<index>`

   Here streams are referenced by `<index>` NOT stream_id. Indicies start at 0... look at the response from GETting from `/api/processors/<processor_id>` to see all streams for a processor.
   
   So, for the example above:
   ```json
     {
       "id": 106,
       "name": "Audio Monitor",
       "parameters": [
         {
           "name": "audio_output",
           "type": "Categorical",
           "value": "BOTH"
         },
         {
           "name": "mute_audio",
           "type": "Boolean",
           "value": "false"
         }
       ],
       "predecessor": 105,
       "streams": {
         "channel_count": 16,
         "id": 10001,
         "name": "example_data",
         "parameters": [
           {
             "name": "enable_stream",
             "type": "Boolean",
             "value": "true"
           },
           {
             "name": "Channels",
             "type": "Selected Channels",
             "value": "8"
           }
         ],
         "sample_rate": 40000,
         "source_id": 100
       }
     }
   ```
   where we see one stream, "example_data", with two parameters, "enable_stream" and "Channels".
  
   Note: the "id" (10001) is not returned by the official API (as at commit 860b671). I've modified the GUI code to return the id for me to debug and document the API.

   I *think* that the stream index for API requests is the *zero based* index of the stream returned in the streams field... so index 0 referrs to the first stream in the list.

4. To get the value of a stream parameter, e.g., 'Channels' in the example 
   above, you can GET from `/api/processors/<processor_id>/streams/<index>/parameters/<parameter_name>`

   For `/api/processors/106/streams/0/Channels`:
   ```json
     {
       "name": "Channels",
       "type": "Selected Channels",
       "value": "8"
     }
   ```
   Note: parameter names are case sensitive!

5. To set the value of a stream parameter for a processor, e.g., Channels 
   for the Audio Monitor processor, PUT to `/api/processors/<processor_id>/streams/<index>/<parameter_name>`
   
   For `/api/processors/106/streams/0/parameters/Channels`
   ```json
     {
       "value": [0,1]
     }
   ```
   in this case, the Audio Monitor processor expects an *array* of up to 4 values... these values are channel indices, so are zero based, i.e., a "value" of 0 selects the first channel (probably channel 1?).

   Note: Matlab's jsonencode() converts cell arrays to arrays in the json string output, so to produce the requisite json string, as above, you need:
   ```matlab
     jsonencode(struct('value',{{0,1}}))
   ```
6. To set global `prepend_text` and/or `append_text`, PUT to
   `/api/recording`
   ```json
     {
       "prepend_text": "subject.paradigm.hhmmss_",
       "append_text": ""
     }
   ```  
   BUT, the standard API provides no way to set the state ('NONE', 'AUTO' or 'CUSTOM') of either the prepend or append text, so this must be 'CUSTOM' in the settings .xml file.
