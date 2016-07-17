#!/usr/bin/env perl

use Modern::Perl;
use Mojolicious::Lite;
use IO::Async::Listener;
use IO::Async::Loop::Mojo;
use Log::Any qw($log);
use JSON::MaybeXS;
use Mojo::Util qw(xml_escape);
use Mojo::DOM;
use Text::Markdown;
use Path::Tiny;
use Encode qw(decode_utf8);

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
	$c->render( template => 'ws', format => 'js' );
};

sub send_update_to_clients {
	return unless $vim_buffer_data;

	my @lines = @{ $vim_buffer_data->{text} };
	my @cursor_pos = (
		$vim_cursor_data->{cursor_position}[1], # line number
		$vim_cursor_data->{cursor_position}[2]  # column
	);
	#my $sentinel_left = "\x{FFFF}";
	#my $sentinel_right = "\x{1FFFF}";
	my $sentinel_left = "\x{FFF0}";
	my $sentinel_right = "\x{1FFF0}";
	my $text = join "\n", map {
		my $current_line = $_ + 1;
		if( defined $cursor_pos[0] && $cursor_pos[0] == $current_line ) {
			my $count_chars_before = $cursor_pos[1]-1;
			$lines[$_] =~ s/(.{$count_chars_before})(.?)/$1$sentinel_left@{[ $2 || ' ' ]}$sentinel_right/r;
		} else {
			$lines[$_]
		}
	} 0..@lines-1;
	my $type = $vim_buffer_data->{ext};

	my $render_html;
	if ( $type eq 'markdown' ) {
		$render_html = Text::Markdown::markdown( $text );
	} elsif ( $type eq 'ikiwiki' ) {
		my $orig_file = path( $vim_buffer_data->{filename} );
		my $tempdir = Path::Tiny->tempdir;
		my $tempfile = $tempdir->child( $orig_file->basename );
		$tempfile->spew_utf8( $text );
		$render_html = `ikiwiki --setup ~/sw_projects/wiki/notebook/notebook.help/notebook.setup --render $tempfile`;
		$render_html = decode_utf8( $render_html );
		$render_html = Mojo::DOM->new( $render_html )
			->find('span.parentlinks')
			->first
			->remove->root->to_string;
	} elsif ( $type eq 'html' ) {
		$render_html = $text;
	} else {
		my $escaped_html = xml_escape $text;
		$render_html = "<pre><code class='$type'>$escaped_html</code></pre>";
	}

	$render_html =~ s,\Q$sentinel_left\E(.?)\Q$sentinel_right\E,<span class="cursor">@{[ $1 ne ' ' ? $1 : '&#x2588;' ]}</span>,ms;


	my $num_of_clients = scalar keys %$clients;
	say $num_of_clients;
	for (keys %$clients) {
		$clients->{$_}->send({json => {
			text =>  $render_html,
			cursor => $vim_cursor_data->{cursor_position}
		}});
	}
}

websocket '/update' => sub {
	my $self = shift;

	app->log->debug(sprintf 'Client connected: %s', $self->tx);
	my $id = sprintf "%s", $self->tx;
	use DDP; p $id;
	$clients->{$id} = $self->tx;

	# infinite timeout
	$self->inactivity_timeout(0);

	#$self->on(message => sub {
		#my ($self, $msg) = @_;
		#send_update_to_clients();
	#});

	$self->on(finish => sub {
		app->log->debug('Client disconnected');
		delete $clients->{$id};
	});
};


app->config(
	hypnotoad => {listen => ["http://*:$http_port"]},
);

app->start;
__DATA__
@@ index.html.ep
<html>
  <head>
    <title>WebSocket Client</title>
    <script
      type="text/javascript"
      src="//ajax.googleapis.com/ajax/libs/jquery/1.8.0/jquery.min.js"></script>
    <script
      type="text/javascript"
      src="//cdnjs.cloudflare.com/ajax/libs/socket.io/0.9.16/socket.io.min.js"></script>
    <script
      type="text/javascript"
      src="/js/ws.js"></script>

    <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.5.0/styles/default.min.css">
    <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.5.0/highlight.min.js"></script>
    <script src="//cdnjs.cloudflare.com/ajax/libs/jquery-scrollTo/2.1.0/jquery.scrollTo.min.js"></script>
    <style>
      .cursor {
        display: inline-block;
        background: #111;
        margin-left: 1px;
      
        -webkit-animation: blink 2s linear 0s infinite;
        -moz-animation: blink 2s linear 0s infinite;
        -ms-animation: blink 2s linear 0s infinite;
        -o-animation: blink 2s linear 0s infinite;
      }

      @-webkit-keyframes blink {
        0%   { background: #0a0 }
        47%  { background: #090 }
        50%  { background: #000 }
        97%  { background: #000 }
        100% { background: #090 }
      }

      @-moz-keyframes blink {
        0%   { background: #0a0 }
        47%  { background: #090 }
        50%  { background: #000 }
        97%  { background: #000 }
        100% { background: #090 }
      }

      @-ms-keyframes blink {
        0%   { background: #0a0 }
        47%  { background: #090 }
        50%  { background: #000 }
        97%  { background: #000 }
        100% { background: #090 }
      }

      @-o-keyframes blink {
        0%   { background: #0a0 }
        47%  { background: #090 }
        50%  { background: #000 }
        97%  { background: #000 }
        100% { background: #090 }
      }
    </style>
  </head>
<body>

<div id="content">
empty
</div>

</body>
</html>
@@ ws.js.ep
$(document).one('ready', function () {
  var log = function (text) {
    $('#content').html( text );
    $('pre code').each(function(i, block) {
      hljs.highlightBlock(block);
    });
    //var offset = {offset: function() { return { top: -$(window).height() / 2 } } };
    var offset = {offset: function() { return { top: -50 } } };
    $('body').scrollTo('.cursor', 0, offset);
  };

  var ws = new WebSocket( '<%= url_for('update')->to_abs %>' );

  ws.onopen = function () {
    console.log('Connection opened');
  };

  ws.onmessage = function (msg) {
    var res = JSON.parse(msg.data);
    log( res.text );
  };
});
