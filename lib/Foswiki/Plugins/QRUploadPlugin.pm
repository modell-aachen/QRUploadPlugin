# See bottom of file for default license and copyright information

package Foswiki::Plugins::QRUploadPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use Filesys::Virtual::Foswiki;

our $VERSION = '1.0';
our $RELEASE = '1.0';

our $SHORTDESCRIPTION = 'Plugin for customer specific changes.';

our $NO_PREFS_IN_TOPIC = 1;

our $value;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler(
        'QRUPLOAD', \&_QRUPLOAD );

    Foswiki::Func::registerRESTHandler( 'upload', \&_restUpload );
    Foswiki::Func::registerRESTHandler( 'form', \&_restForm );

    # Plugin correctly initialized
    return 1;
}

sub _restUpload {
    my ( $session, $subject, $verb, $response ) = @_;

    my $query = $session->{request};
    my $token = $query->param('token');

    my %opts = (validateLogin => 0);
    my $fs = Filesys::Virtual::Foswiki->new(\%opts);
    my $db = $fs->_locks();
    my $auth = $db->getAuthToken($token);

    unless(ref $auth && $auth->{user}) {
        $response->status(403);
        return 'authentication failed';
    }

    $session->{user} = $auth->{user};
    my ($w, $t) = Foswiki::Func::normalizeWebTopicName( $auth->{web}, $auth->{topic} );

    my $filename = $query->param('filename');
    my $stream = $query->upload('filename');
    my $tmp = $query->tmpFileName($filename);
    my $size = -s $tmp;

    # TODO catch ACL exceptions
    Foswiki::Func::saveAttachment(
        $w,
        $t,
        $filename,
        {
            tmpFilename => $tmp,
            stream => $stream,
            filepath => $filename,
            filesize => $size
        }
    );

    return 'OK';

}

sub _restForm {
    my ( $session, $subject, $verb, $response ) = @_;

    my $query = $session->{request};
    my $token = $query->param('token');

    my %opts = (validateLogin => 0);
    my $fs = Filesys::Virtual::Foswiki->new(\%opts);
    my $db = $fs->_locks();
    my $auth = $db->getAuthToken($token);

    unless(ref $auth && $auth->{user}) {
        $response->status(403);
        return 'authentication failed';
    }

    $session->{user} = $auth->{user};

    my $template = $auth->{template} || 'MobileUpload';
    my $web = $auth->{web};
    if($web) {
        Foswiki::Func::setPreferencesValue('WEB', $web);
        Foswiki::Func::setPreferencesValue('BASEWEB', $web);
        Foswiki::Func::setPreferencesValue('INCLUDINGWEB', $web);
    }
    my $topic = $auth->{topic};
    if($topic) {
        Foswiki::Func::setPreferencesValue('TOPIC', $topic);
        Foswiki::Func::setPreferencesValue('BASETOPIC', $topic);
        Foswiki::Func::setPreferencesValue('INCLUDINGTOPIC', $topic);
    }
    my $skin = $auth->{skin};

    my $base = $auth->{base} || die;
    Foswiki::Func::setPreferencesValue('QRBASE', $base);

    my $accept = $auth->{accept} || 'image/*';
    Foswiki::Func::setPreferencesValue('QRUACCEPT', $accept);

    my $multiple = (not defined $auth->{multiple} || $auth->{multiple}) ? "multiple='multiple'" : '';
    Foswiki::Func::setPreferencesValue('QRUMULTIPLE', $multiple);

    my $html = Foswiki::Func::loadTemplate($template, $skin, $web);
    $html = Foswiki::Func::expandCommonVariables($html);
    $html = Foswiki::Func::renderText($html);

    return $html;
}

sub _QRUPLOAD {
    my ( $session, $attributes, $defaulttopic, $defaultweb ) = @_;

    # TODO: "validate" clients (client shows an id, user can accept that id at the QR code)
    # TODO: expiry
    # TODO: popup-window when clicked inside browsers

    return '' if Foswiki::Func::isGuest();

    my $web = $attributes->{web} || $defaultweb;
    my $topic = $attributes->{topic} || $defaulttopic;
    ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);

    my $base = $Foswiki::cfg{Extensions}{QRUploadPlugin}{base} || '%SCRIPTURL{rest}%';
    $base = Foswiki::Func::expandCommonVariables($base);
    my $wikiName = $session->{user};
    my $path = "$web/$topic";
    my %opts = (validateLogin => 0);

    use JSON;
    require Filesys::Virtual::Foswiki;
    my $fs = Filesys::Virtual::Foswiki->new(\%opts);
    my $db = $fs->_locks();
    my %data = (user => $wikiName, path => $path, file => $wikiName, web => $web, topic => $topic, base => $base);
    if($attributes->{accept}) {
        $data{accept} = $attributes->{accept};
    }
    if($attributes->{multiple}) {
        $data{multiple} = $attributes->{multiple};
    }
    my $token = Digest::SHA::sha1_hex( encode_json( \%data ) . rand(1_000_000). rand(1_000_000) );
    unless ( $db->setAuthToken( $token, \%data ) ) {
        return '%MAKETEXT{"QRUPLOAD: Could not set token"}%'; # TODO proper error; test this
    }

    my $modulesize = $attributes->{modulesize} || 4;
    my $version = $attributes->{version} || 9; # XXX do proper autodetection (the one from the module does not work)

    my $url = "$base/mobileupload/$token";

    use GD::Barcode::QRcode;
    use MIME::Base64;

    my $code = '<img src="data:image/png;base64,' . MIME::Base64::encode(GD::Barcode::QRcode->new($url, {ModuleSize => $modulesize, Version => $version})->plot->png, '') . '" />';

    unless($attributes->{nolink}) {
        $code = '<a href="'.$url.'" title="%MAKETEXT{"Upload to [_1]" args="'."$web/$topic".'"}%">'.$code.'</a>';
    }

    return $code;
}


1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
