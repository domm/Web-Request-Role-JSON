package Web::Request::Role::JSON;

# ABSTRACT: JSON helpers for Web::Request

our $VERSION = '1.000';

use 5.010;
use Moose::Role;
use JSON::MaybeXS;
use Encode;

sub decoded_json_content {
    my $self = shift;

    # Web::Request->content will decode content based on
    # $req->encoding, which is utf8 for JSON. So $content has UTF8 flag
    # on, which means we have to tell JSON::MaybeXS to turn
    # utf8-handling OFF

    return JSON::MaybeXS->new(utf8=>0)->decode($self->content);

    # Alternatives:
    # - reencode the content (stupid because double the work)
    #   decode_json(encode_utf8($self->content))
    # - set $self->encoding(undef), and set it back after decoding
}

sub new_json_response {
    my ( $self, $data, $header_hash, $status ) = @_;
    my $headers =
        ref($header_hash)
        ? HTTP::Headers->new(%$header_hash)
        : HTTP::Headers->new;
    $headers->header( 'content-type' => 'application/json' );
    $status ||= 200;

    return $self->new_response(
        headers => $headers,
        status  => $status,
        content => decode_utf8( encode_json($data) ),
    );
}

sub new_json_error {
    my ( $self, $message, $status ) = @_;
    $status ||= 400;
    my $body;
    if ( ref($message) ) {
        $body = $message;
    }
    else {
        $body = { status => 'error', message => "$message" };
    }

    return $self->new_response(
        headers => [ content_type => 'application/json' ],
        status  => $status,
        content => decode_utf8( encode_json($body) ),
    );
}

1;

=head1 SYNOPSIS

  # Create a request handler
  package My::App::Request;
  use Moose;
  extends 'Web::Request';
  with 'Web::Request::Role::JSON';

  # Make sure your app uses your Request class, e.g. using OX:
  package My::App::OX;
  sub request_class {'My::App::Request'}

  # Finally, in some controller action

=head1 DESCRIPTION

=head1 THANKS

Thanks to

=over

=item *

L<validad.com|https://www.validad.com/> for supporting Open Source.

=back

