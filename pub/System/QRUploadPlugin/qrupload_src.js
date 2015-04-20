jQuery(function($){
        $('.qrupload.filepicker').change(function(evt) {
                var $form = $(this).closest('form');

                var files = evt.target.files;
                $.each(files, function(idx, item) {
                        var payload = new FormData();
                        payload.append("filepath", item);
                        payload.append("filename", item.name);
                        payload.append("filecomment", '');
                        payload.append("token", $form.find('[name="token"]').val());

                        var client = new XMLHttpRequest();
                        if(window.console) {
                            client.onerror = window.console;
                            client.onabort = window.console;
                        }

                        client.onreadystatechange = function(){
                            if(client.readyState != 4) return;
                            var response = client.responseText;
                            if(client.status == 200) {
                                $container.find('.progress').css('background-color', 'green');
                                if(!response) response = 'OK';
                            } else {
                                $container.find('.progress').css('background-color', 'red');
                                if(!response) response = 'unknown';
                                response = 'Error: ' + response;
                            }
                            $tr.find('.result').append(response);
                        };

                        var $tr = $('<tr><td class="name"></td><td class="status"></td><td class="result"></td></tr>').appendTo('.progressContainer tbody');
                        $tr.find('.name').text(item.name);
                        var $container = $('<div></div>').css('border', '1px solid black').css('padding', '2px').css('width', '200px');
                        $container.append($('<div></div>').css('height', '5px').css('background-color', 'blue').css('width', 0).addClass('progress'));
                        $tr.find('.status').append($container);
                        client.upload.onprogress = function( evt ) {
                          var val = Math.round( 100/evt.total * evt.loaded );
                          var percent = val + '%';

                          $container.find('div.progress').css('width', percent);

                          // continue with next file
                          if ( val === 100 ) {
                    //        if ( isAutoUpload( id ) ) {
                    //          uploadNext( id );
                    //        }
                          }
                        };

                        var uploadurl = $form.attr('action');

                          client.open( "POST", uploadurl );
                          client.send( payload );
                });
        });
});
