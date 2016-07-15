#!/usr/bin/env perl

use Modern::Perl;
use Mojolicious::Lite;
use IO::Async::Listener;
use IO::Async::Loop::Mojo;
use Log::Any qw($log);
use JSON::MaybeXS;

my $vim_port = 20345;
my $http_port = 20346;

my $json_coder = JSON::MaybeXS->new->utf8->allow_nonref;

my $vim_buffer_data;
my $vim_cursor_data;

my $clients = {};

my $loop = IO::Async::Loop::Mojo->new();

my $vim_listener = IO::Async::Listener->new(
	on_stream => sub {
		my ( undef, $stream ) = @_;

		$stream->configure(
			on_read => sub {
				my ( $self, $buffref, $eof ) = @_;

				return 0 unless $$buffref;

				my $data_array = decode_json( $$buffref );

				my $data = $data_array->[1];

				use DDP; p $data;

				if( $data->{event} eq 'update' ) {
					$vim_buffer_data = $data;
				} elsif( $data->{event} eq 'move' ) {
					$vim_cursor_data = $data;
				}

				$self->write( "" );
				$$buffref = "";

				send_update_to_clients();

				return 0;
			},
		);

		$loop->add( $stream );
	}
);

$loop->add( $vim_listener );

$vim_listener->listen(
	addr => {
		family   => "inet",
		socktype => "stream",
		port     => $vim_port,
	},
	on_listen_error => sub {
		...
	},
);

#$socket->connect(

get '/' => 'index';
get '/js/ws.js' => sub {
	my $c = shift;
	my $ws_port = $c->tx->local_port;
	my $ws_uri = "ws://localhost:$ws_port/update";
	$c->stash( ws_uri => $json_coder->encode( $ws_uri ) );
	$c->render( template => 'ws', format => 'js' );
};

sub send_update_to_clients {
	use DDP; p $clients;
	return unless $vim_buffer_data;
	for (keys %$clients) {
		$clients->{$_}->send({json => {
			hms  => "...",
			text => $vim_buffer_data->{text},
		}});
	}
}

websocket '/update' => sub {
	my $self = shift;

	app->log->debug(sprintf 'Client connected: %s', $self->tx);
	my $id = sprintf "%s", $self->tx;
	$clients->{$id} = $self->tx;

	$self->on(message => sub {
		my ($self, $msg) = @_;
		send_update_to_clients();
	});

	$self->on(finish => sub {
		app->log->debug('Client disconnected');
		delete $clients->{$id};
	});
};


app->config(
	hypnotoad => {listen => ["http://*:$http_port"]},
);

use DDP;p app->config;

app->start;
__DATA__
@@ index.html.ep
<html>
  <head>
    <title>WebSocket Client</title>
    <script
      type="text/javascript"
      src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"
    ></script>
    <script type="text/javascript" src="/js/ws.js"></script>
    <style type="text/css">
      textarea {
          width: 40em;
          height:10em;
      }
    </style>
  </head>
<body>

<h1>Mojolicious + WebSocket</h1>

<p><input type="text" id="msg" /></p>
<textarea id="log" readonly></textarea>

</body>
</html>
@@ ws.js.ep
$(function () {
  $('#msg').focus();

  var log = function (text) {
    $('#log').val( $('#log').val() + text + "\n");
  };

  var ws = new WebSocket( <%== $ws_uri %> );
  ws.onopen = function () {
    log('Connection opened');
  };

  ws.onmessage = function (msg) {
    var res = JSON.parse(msg.data);
    log('[' + res.hms + '] ' + res.text);
  };

$('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send($('#msg').val());
        $('#msg').val('');
    }
  });
});
