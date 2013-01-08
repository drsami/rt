# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 NAME

  RT::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION



=head1 METHODS

=cut

package RT::Record;

use strict;
use warnings;


use RT::Date;
use RT::User;
use RT::Attributes;
use RT::Link;
use Encode qw();

our $_TABLE_ATTR = { };
use base RT->Config->Get('RecordBaseClass');
use base 'RT::Base';


sub _Init {
    my $self = shift;
    $self->_BuildTableAttributes unless ($_TABLE_ATTR->{ref($self)});
    $self->CurrentUser(@_);
}



=head2 _PrimaryKeys

The primary keys for RT classes is 'id'

=cut

sub _PrimaryKeys { return ['id'] }
# short circuit many, many thousands of calls from searchbuilder
sub _PrimaryKey { 'id' }

=head2 Id

Override L<DBIx::SearchBuilder/Id> to avoid a few lookups RT doesn't do
on a very common codepath

C<id> is an alias to C<Id> and is the preferred way to call this method.

=cut

sub Id {
    return shift->{'values'}->{id};
}

*id = \&Id;

=head2 Delete

Delete this record object from the database.

=cut

sub Delete {
    my $self = shift;
    my ($rv) = $self->SUPER::Delete;
    if ($rv) {
        return ($rv, $self->loc("Object deleted"));
    } else {

        return(0, $self->loc("Object could not be deleted"))
    } 
}

=head2 RecordType

Returns a string which is this record's type. It's not localized and by
default last part (everything after last ::) of class name is returned.

=cut

sub RecordType {
    my $res = ref($_[0]) || $_[0];
    $res =~ s/.*:://;
    return $res;
}

=head2 ObjectTypeStr

DEPRECATED. Stays here for backwards. Returns localized L</RecordType>.

=cut

# we deprecate because of:
# * ObjectType is used in several classes with ObjectId to store
#   records of different types, for example transactions use those
#   and it's unclear what this method should return 'Transaction'
#   or type of referenced record
# * returning localized thing is not good idea

sub ObjectTypeStr {
    my $self = shift;
    RT->Deprecated(
        Remove => "4.4",
        Instead => "RecordType",
    );
    return $self->loc( $self->RecordType( @_ ) );
}

=head2 Attributes

Return this object's attributes as an RT::Attributes object

=cut

sub Attributes {
    my $self = shift;
    unless ($self->{'attributes'}) {
        $self->{'attributes'} = RT::Attributes->new($self->CurrentUser);
        $self->{'attributes'}->LimitToObject($self);
        $self->{'attributes'}->OrderByCols({FIELD => 'id'});
    }
    return ($self->{'attributes'});
}


=head2 AddAttribute { Name, Description, Content }

Adds a new attribute for this object.

=cut

sub AddAttribute {
    my $self = shift;
    my %args = ( Name        => undef,
                 Description => undef,
                 Content     => undef,
                 @_ );

    my $attr = RT::Attribute->new( $self->CurrentUser );
    my ( $id, $msg ) = $attr->Create( 
                                      Object    => $self,
                                      Name        => $args{'Name'},
                                      Description => $args{'Description'},
                                      Content     => $args{'Content'} );


    # XXX TODO: Why won't RedoSearch work here?                                     
    $self->Attributes->_DoSearch;
    
    return ($id, $msg);
}


=head2 SetAttribute { Name, Description, Content }

Like AddAttribute, but replaces all existing attributes with the same Name.

=cut

sub SetAttribute {
    my $self = shift;
    my %args = ( Name        => undef,
                 Description => undef,
                 Content     => undef,
                 @_ );

    my @AttributeObjs = $self->Attributes->Named( $args{'Name'} )
        or return $self->AddAttribute( %args );

    my $AttributeObj = pop( @AttributeObjs );
    $_->Delete foreach @AttributeObjs;

    $AttributeObj->SetDescription( $args{'Description'} );
    $AttributeObj->SetContent( $args{'Content'} );

    $self->Attributes->RedoSearch;
    return 1;
}

=head2 DeleteAttribute NAME

Deletes all attributes with the matching name for this object.

=cut

sub DeleteAttribute {
    my $self = shift;
    my $name = shift;
    my ($val,$msg) =  $self->Attributes->DeleteEntry( Name => $name );
    $self->ClearAttributes;
    return ($val,$msg);
}

=head2 FirstAttribute NAME

Returns the first attribute with the matching name for this object (as an
L<RT::Attribute> object), or C<undef> if no such attributes exist.
If there is more than one attribute with the matching name on the
object, the first value that was set is returned.

=cut

sub FirstAttribute {
    my $self = shift;
    my $name = shift;
    return ($self->Attributes->Named( $name ))[0];
}


sub ClearAttributes {
    my $self = shift;
    delete $self->{'attributes'};

}

sub _Handle { return $RT::Handle }



=head2  Create PARAMHASH

Takes a PARAMHASH of Column -> Value pairs.
If any Column has a Validate$PARAMNAME subroutine defined and the 
value provided doesn't pass validation, this routine returns
an error.

If this object's table has any of the following atetributes defined as
'Auto', this routine will automatically fill in their values.

=over

=item Created

=item Creator

=item LastUpdated

=item LastUpdatedBy

=back

=cut

sub Create {
    my $self    = shift;
    my %attribs = (@_);
    foreach my $key ( keys %attribs ) {
        if (my $method = $self->can("Validate$key")) {
        if (! $method->( $self, $attribs{$key} ) ) {
            if (wantarray) {
                return ( 0, $self->loc('Invalid value for [_1]', $key) );
            }
            else {
                return (0);
            }
        }
        }
    }



    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$ydaym,$isdst,$offset) = gmtime();

    my $now_iso =
     sprintf("%04d-%02d-%02d %02d:%02d:%02d", ($year+1900), ($mon+1), $mday, $hour, $min, $sec);

    $attribs{'Created'} = $now_iso if ( $self->_Accessible( 'Created', 'auto' ) && !$attribs{'Created'});

    if ($self->_Accessible( 'Creator', 'auto' ) && !$attribs{'Creator'}) {
         $attribs{'Creator'} = $self->CurrentUser->id || '0'; 
    }
    $attribs{'LastUpdated'} = $now_iso
      if ( $self->_Accessible( 'LastUpdated', 'auto' ) && !$attribs{'LastUpdated'});

    $attribs{'LastUpdatedBy'} = $self->CurrentUser->id || '0'
      if ( $self->_Accessible( 'LastUpdatedBy', 'auto' ) && !$attribs{'LastUpdatedBy'});

    my $id = $self->SUPER::Create(%attribs);
    if ( UNIVERSAL::isa( $id, 'Class::ReturnValue' ) ) {
        if ( $id->errno ) {
            if (wantarray) {
                return ( 0,
                    $self->loc( "Internal Error: [_1]", $id->{error_message} ) );
            }
            else {
                return (0);
            }
        }
    }
    # If the object was created in the database, 
    # load it up now, so we're sure we get what the database 
    # has.  Arguably, this should not be necessary, but there
    # isn't much we can do about it.

   unless ($id) { 
    if (wantarray) {
        return ( $id, $self->loc('Object could not be created') );
    }
    else {
        return ($id);
    }

   }

    if  (UNIVERSAL::isa('errno',$id)) {
        return(undef);
    }

    $self->Load($id) if ($id);



    if (wantarray) {
        return ( $id, $self->loc('Object created') );
    }
    else {
        return ($id);
    }

}



=head2 LoadByCols

Override DBIx::SearchBuilder::LoadByCols to do case-insensitive loads if the 
DB is case sensitive

=cut

sub LoadByCols {
    my $self = shift;

    # We don't want to hang onto this
    $self->ClearAttributes;

    return $self->SUPER::LoadByCols( @_ ) unless $self->_Handle->CaseSensitive;

    # If this database is case sensitive we need to uncase objects for
    # explicit loading
    my %hash = (@_);
    foreach my $key ( keys %hash ) {

        # If we've been passed an empty value, we can't do the lookup. 
        # We don't need to explicitly downcase integers or an id.
        if ( $key ne 'id' && defined $hash{ $key } && $hash{ $key } !~ /^\d+$/ ) {
            my ($op, $val, $func);
            ($key, $op, $val, $func) =
                $self->_Handle->_MakeClauseCaseInsensitive( $key, '=', delete $hash{ $key } );
            $hash{$key}->{operator} = $op;
            $hash{$key}->{value}    = $val;
            $hash{$key}->{function} = $func;
        }
    }
    return $self->SUPER::LoadByCols( %hash );
}



# There is room for optimizations in most of those subs:


sub LastUpdatedObj {
    my $self = shift;
    my $obj  = RT::Date->new( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->LastUpdated );
    return $obj;
}



sub CreatedObj {
    my $self = shift;
    my $obj  = RT::Date->new( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->Created );

    return $obj;
}


# B<DEPRECATED> and will be removed in 4.4
sub AgeAsString {
    my $self = shift;
    RT->Deprecated(
        Remove => "4.4",
        Instead => "->CreatedObj->AgeAsString",
    );
    return ( $self->CreatedObj->AgeAsString() );
}

# B<DEPRECATED> and will be removed in 4.4
sub LongSinceUpdateAsString {
    my $self = shift;
    RT->Deprecated(
        Remove => "4.4",
        Instead => "->LastUpdatedObj->AgeAsString",
    );
    if ( $self->LastUpdated ) {
        return ( $self->LastUpdatedObj->AgeAsString() );
    } else {
        return "never";
    }
}

sub LastUpdatedAsString {
    my $self = shift;
    if ( $self->LastUpdated ) {
        return ( $self->LastUpdatedObj->AsString() );
    } else {
        return "never";
    }
}

sub CreatedAsString {
    my $self = shift;
    return ( $self->CreatedObj->AsString() );
}

sub _Set {
    my $self = shift;

    my %args = (
        Field => undef,
        Value => undef,
        IsSQL => undef,
        @_
    );

    #if the user is trying to modify the record
    # TODO: document _why_ this code is here

    if ( ( !defined( $args{'Field'} ) ) || ( !defined( $args{'Value'} ) ) ) {
        $args{'Value'} = 0;
    }

    my $old_val = $self->__Value($args{'Field'});
     $self->_SetLastUpdated();
    my $ret = $self->SUPER::_Set(
        Field => $args{'Field'},
        Value => $args{'Value'},
        IsSQL => $args{'IsSQL'}
    );
        my ($status, $msg) =  $ret->as_array();

        # @values has two values, a status code and a message.

    # $ret is a Class::ReturnValue object. as such, in a boolean context, it's a bool
    # we want to change the standard "success" message
    if ($status) {
        if ($self->SQLType( $args{'Field'}) =~ /text/) {
            $msg = $self->loc(
                "[_1] updated",
                $self->loc( $args{'Field'} ),
            );
        } else {
            $msg = $self->loc(
                "[_1] changed from [_2] to [_3]",
                $self->loc( $args{'Field'} ),
                ( $old_val ? '"' . $old_val . '"' : $self->loc("(no value)") ),
                '"' . $self->__Value( $args{'Field'}) . '"',
            );
        }
    } else {
        $msg = $self->CurrentUser->loc_fuzzy($msg);
    }

    return wantarray ? ($status, $msg) : $ret;
}



=head2 _SetLastUpdated

This routine updates the LastUpdated and LastUpdatedBy columns of the row in question
It takes no options. Arguably, this is a bug

=cut

sub _SetLastUpdated {
    my $self = shift;
    use RT::Date;
    my $now = RT::Date->new( $self->CurrentUser );
    $now->SetToNow();

    if ( $self->_Accessible( 'LastUpdated', 'auto' ) ) {
        my ( $msg, $val ) = $self->__Set(
            Field => 'LastUpdated',
            Value => $now->ISO
        );
    }
    if ( $self->_Accessible( 'LastUpdatedBy', 'auto' ) ) {
        my ( $msg, $val ) = $self->__Set(
            Field => 'LastUpdatedBy',
            Value => $self->CurrentUser->id
        );
    }
}



=head2 CreatorObj

Returns an RT::User object with the RT account of the creator of this row

=cut

sub CreatorObj {
    my $self = shift;
    unless ( exists $self->{'CreatorObj'} ) {

        $self->{'CreatorObj'} = RT::User->new( $self->CurrentUser );
        $self->{'CreatorObj'}->Load( $self->Creator );
    }
    return ( $self->{'CreatorObj'} );
}



=head2 LastUpdatedByObj

  Returns an RT::User object of the last user to touch this object

=cut

sub LastUpdatedByObj {
    my $self = shift;
    unless ( exists $self->{LastUpdatedByObj} ) {
        $self->{'LastUpdatedByObj'} = RT::User->new( $self->CurrentUser );
        $self->{'LastUpdatedByObj'}->Load( $self->LastUpdatedBy );
    }
    return $self->{'LastUpdatedByObj'};
}



=head2 URI

Returns this record's URI

=cut

sub URI {
    my $self = shift;
    my $uri = RT::URI::fsck_com_rt->new($self->CurrentUser);
    return($uri->URIForObject($self));
}


=head2 ValidateName NAME

Validate the name of the record we're creating. Mostly, just make sure it's not a numeric ID, which is invalid for Name

=cut

sub ValidateName {
    my $self = shift;
    my $value = shift;
    if (defined $value && $value=~ /^\d+$/) {
        return(0);
    } else  {
        return(1);
    }
}



=head2 SQLType attribute

return the SQL type for the attribute 'attribute' as stored in _ClassAccessible

=cut

sub SQLType {
    my $self = shift;
    my $field = shift;

    return ($self->_Accessible($field, 'type'));


}

sub __Value {
    my $self  = shift;
    my $field = shift;
    my %args  = ( decode_utf8 => 1, @_ );

    unless ($field) {
        $RT::Logger->error("__Value called with undef field");
    }

    my $value = $self->SUPER::__Value($field);

    return undef if (!defined $value);

    if ( $args{'decode_utf8'} ) {
        if ( !utf8::is_utf8($value) ) {
            utf8::decode($value);
        }
    }
    else {
        if ( utf8::is_utf8($value) ) {
            utf8::encode($value);
        }
    }

    return $value;

}

# Set up defaults for DBIx::SearchBuilder::Record::Cachable

sub _CacheConfig {
  {
     'cache_p'        => 1,
     'cache_for_sec'  => 30,
  }
}



sub _BuildTableAttributes {
    my $self = shift;
    my $class = ref($self) || $self;

    my $attributes;
    if ( UNIVERSAL::can( $self, '_CoreAccessible' ) ) {
       $attributes = $self->_CoreAccessible();
    } elsif ( UNIVERSAL::can( $self, '_ClassAccessible' ) ) {
       $attributes = $self->_ClassAccessible();

    }

    foreach my $column (keys %$attributes) {
        foreach my $attr ( keys %{ $attributes->{$column} } ) {
            $_TABLE_ATTR->{$class}->{$column}->{$attr} = $attributes->{$column}->{$attr};
        }
    }
    foreach my $method ( qw(_OverlayAccessible _VendorAccessible _LocalAccessible) ) {
        next unless UNIVERSAL::can( $self, $method );
        $attributes = $self->$method();

        foreach my $column ( keys %$attributes ) {
            foreach my $attr ( keys %{ $attributes->{$column} } ) {
                $_TABLE_ATTR->{$class}->{$column}->{$attr} = $attributes->{$column}->{$attr};
            }
        }
    }
}


=head2 _ClassAccessible 

Overrides the "core" _ClassAccessible using $_TABLE_ATTR. Behaves identical to the version in
DBIx::SearchBuilder::Record

=cut

sub _ClassAccessible {
    my $self = shift;
    return $_TABLE_ATTR->{ref($self) || $self};
}

=head2 _Accessible COLUMN ATTRIBUTE

returns the value of ATTRIBUTE for COLUMN


=cut 

sub _Accessible  {
  my $self = shift;
  my $column = shift;
  my $attribute = lc(shift);
  return 0 unless defined ($_TABLE_ATTR->{ref($self)}->{$column});
  return $_TABLE_ATTR->{ref($self)}->{$column}->{$attribute} || 0;

}

=head2 _EncodeLOB BODY MIME_TYPE

Takes a potentially large attachment. Returns (ContentEncoding, EncodedBody) based on system configuration and selected database

=cut

sub _EncodeLOB {
        my $self = shift;
        my $Body = shift;
        my $MIMEType = shift || '';
        my $Filename = shift;

        my $ContentEncoding = 'none';

        #get the max attachment length from RT
        my $MaxSize = RT->Config->Get('MaxAttachmentSize');

        #if the current attachment contains nulls and the
        #database doesn't support embedded nulls

        if ( ( !$RT::Handle->BinarySafeBLOBs ) && ( $Body =~ /\x00/ ) ) {

            # set a flag telling us to mimencode the attachment
            $ContentEncoding = 'base64';

            #cut the max attchment size by 25% (for mime-encoding overhead.
            $RT::Logger->debug("Max size is $MaxSize");
            $MaxSize = $MaxSize * 3 / 4;
        # Some databases (postgres) can't handle non-utf8 data
        } elsif (    !$RT::Handle->BinarySafeBLOBs
                  && $MIMEType !~ /text\/plain/gi
                  && !Encode::is_utf8( $Body, 1 ) ) {
              $ContentEncoding = 'quoted-printable';
        }

        #if the attachment is larger than the maximum size
        if ( ($MaxSize) and ( $MaxSize < length($Body) ) ) {

            # if we're supposed to truncate large attachments
            if (RT->Config->Get('TruncateLongAttachments')) {

                # truncate the attachment to that length.
                $Body = substr( $Body, 0, $MaxSize );

            }

            # elsif we're supposed to drop large attachments on the floor,
            elsif (RT->Config->Get('DropLongAttachments')) {

                # drop the attachment on the floor
                $RT::Logger->info( "$self: Dropped an attachment of size "
                                   . length($Body));
                $RT::Logger->info( "It started: " . substr( $Body, 0, 60 ) );
                $Filename .= ".txt" if $Filename;
                return ("none", "Large attachment dropped", "plain/text", $Filename );
            }
        }

        # if we need to mimencode the attachment
        if ( $ContentEncoding eq 'base64' ) {

            # base64 encode the attachment
            Encode::_utf8_off($Body);
            $Body = MIME::Base64::encode_base64($Body);

        } elsif ($ContentEncoding eq 'quoted-printable') {
            Encode::_utf8_off($Body);
            $Body = MIME::QuotedPrint::encode($Body);
        }


        return ($ContentEncoding, $Body, $MIMEType, $Filename );

}

sub _DecodeLOB {
    my $self            = shift;
    my $ContentType     = shift || '';
    my $ContentEncoding = shift || 'none';
    my $Content         = shift;

    if ( $ContentEncoding eq 'base64' ) {
        $Content = MIME::Base64::decode_base64($Content);
    }
    elsif ( $ContentEncoding eq 'quoted-printable' ) {
        $Content = MIME::QuotedPrint::decode($Content);
    }
    elsif ( $ContentEncoding && $ContentEncoding ne 'none' ) {
        return ( $self->loc( "Unknown ContentEncoding [_1]", $ContentEncoding ) );
    }
    if ( RT::I18N::IsTextualContentType($ContentType) ) {
       $Content = Encode::decode_utf8($Content) unless Encode::is_utf8($Content);
    }
        return ($Content);
}

=head2 Update  ARGSHASH

Updates fields on an object for you using the proper Set methods,
skipping unchanged values.

 ARGSRef => a hashref of attributes => value for the update
 AttributesRef => an arrayref of keys in ARGSRef that should be updated
 AttributePrefix => a prefix that should be added to the attributes in AttributesRef
                    when looking up values in ARGSRef
                    Bare attributes are tried before prefixed attributes

Returns a list of localized results of the update

=cut

sub Update {
    my $self = shift;

    my %args = (
        ARGSRef         => undef,
        AttributesRef   => undef,
        AttributePrefix => undef,
        @_
    );

    my $attributes = $args{'AttributesRef'};
    my $ARGSRef    = $args{'ARGSRef'};
    my %new_values;

    # gather all new values
    foreach my $attribute (@$attributes) {
        my $value;
        if ( defined $ARGSRef->{$attribute} ) {
            $value = $ARGSRef->{$attribute};
        }
        elsif (
            defined( $args{'AttributePrefix'} )
            && defined(
                $ARGSRef->{ $args{'AttributePrefix'} . "-" . $attribute }
            )
          ) {
            $value = $ARGSRef->{ $args{'AttributePrefix'} . "-" . $attribute };

        }
        else {
            next;
        }

        $value =~ s/\r\n/\n/gs;

        # If Queue is 'General', we want to resolve the queue name for
        # the object.

        # This is in an eval block because $object might not exist.
        # and might not have a Name method. But "can" won't find autoloaded
        # items. If it fails, we don't care
        do {
            no warnings "uninitialized";
            local $@;
            eval {
                my $object = $attribute . "Obj";
                my $name = $self->$object->Name;
                next if $name eq $value || $name eq ($value || 0);
            };

            my $current = $self->$attribute();
            # RT::Queue->Lifecycle returns a Lifecycle object instead of name
            $current = eval { $current->Name } if ref $current;
            next if $value eq $current;
            next if ( $value || 0 ) eq $current;
        };

        $new_values{$attribute} = $value;
    }

    return $self->_UpdateAttributes(
        Attributes => $attributes,
        NewValues  => \%new_values,
    );
}

sub _UpdateAttributes {
    my $self = shift;
    my %args = (
        Attributes => [],
        NewValues  => {},
        @_,
    );

    my @results;

    foreach my $attribute (@{ $args{Attributes} }) {
        next if !exists($args{NewValues}{$attribute});

        my $value = $args{NewValues}{$attribute};
        my $method = "Set$attribute";
        my ( $code, $msg ) = $self->$method($value);
        my ($prefix) = ref($self) =~ /RT(?:.*)::(\w+)/;

        # Default to $id, but use name if we can get it.
        my $label = $self->id;
        $label = $self->Name if (UNIVERSAL::can($self,'Name'));
        # this requires model names to be loc'ed.

=for loc

    "Ticket" # loc
    "User" # loc
    "Group" # loc
    "Queue" # loc

=cut

        push @results, $self->loc( $prefix ) . " $label: ". $msg;

=for loc

                                   "[_1] could not be set to [_2].",       # loc
                                   "That is already the current value",    # loc
                                   "No value sent to _Set!",               # loc
                                   "Illegal value for [_1]",               # loc
                                   "The new value has been set.",          # loc
                                   "No column specified",                  # loc
                                   "Immutable field",                      # loc
                                   "Nonexistant field?",                   # loc
                                   "Invalid data",                         # loc
                                   "Couldn't find row",                    # loc
                                   "Missing a primary key?: [_1]",         # loc
                                   "Found Object",                         # loc

=cut

    }

    return @results;
}




=head2 Members

  This returns an RT::Links object which references all the tickets 
which are 'MembersOf' this ticket

=cut

sub Members {
    my $self = shift;
    return ( $self->_Links( 'Target', 'MemberOf' ) );
}



=head2 MemberOf

  This returns an RT::Links object which references all the tickets that this
ticket is a 'MemberOf'

=cut

sub MemberOf {
    my $self = shift;
    return ( $self->_Links( 'Base', 'MemberOf' ) );
}



=head2 RefersTo

  This returns an RT::Links object which shows all references for which this ticket is a base

=cut

sub RefersTo {
    my $self = shift;
    return ( $self->_Links( 'Base', 'RefersTo' ) );
}



=head2 ReferredToBy

This returns an L<RT::Links> object which shows all references for which this ticket is a target

=cut

sub ReferredToBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'RefersTo' ) );
}



=head2 DependedOnBy

  This returns an RT::Links object which references all the tickets that depend on this one

=cut

sub DependedOnBy {
    my $self = shift;
    return ( $self->_Links( 'Target', 'DependsOn' ) );
}




=head2 HasUnresolvedDependencies

Takes a paramhash of Type (default to '__any').  Returns the number of
unresolved dependencies, if $self->UnresolvedDependencies returns an
object with one or more members of that type.  Returns false
otherwise.

=cut

sub HasUnresolvedDependencies {
    my $self = shift;
    my %args = (
        Type   => undef,
        @_
    );

    my $deps = $self->UnresolvedDependencies;

    if ($args{Type}) {
        $deps->LimitType( VALUE => $args{Type} );
    } else {
        $deps->IgnoreType;
    }

    if ($deps->Count > 0) {
        return $deps->Count;
    }
    else {
        return (undef);
    }
}



=head2 UnresolvedDependencies

Returns an RT::Tickets object of tickets which this ticket depends on
and which have a status of new, open or stalled. (That list comes from
RT::Queue->ActiveStatusArray

=cut


sub UnresolvedDependencies {
    my $self = shift;
    my $deps = RT::Tickets->new($self->CurrentUser);

    $deps->LimitToActiveStatus;
    $deps->LimitDependedOnBy($self->Id);

    return($deps);

}



=head2 AllDependedOnBy

Returns an array of RT::Ticket objects which (directly or indirectly)
depends on this ticket; takes an optional 'Type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the recursive
dependency search.

=cut

sub AllDependedOnBy {
    my $self = shift;
    return $self->_AllLinkedTickets( LinkType => 'DependsOn',
                                     Direction => 'Target', @_ );
}

=head2 AllDependsOn

Returns an array of RT::Ticket objects which this ticket (directly or
indirectly) depends on; takes an optional 'Type' argument in the param
hash, which will limit returned tickets to that type, as well as cause
tickets with that type to serve as 'leaf' nodes that stops the
recursive dependency search.

=cut

sub AllDependsOn {
    my $self = shift;
    return $self->_AllLinkedTickets( LinkType => 'DependsOn',
                                     Direction => 'Base', @_ );
}

sub _AllLinkedTickets {
    my $self = shift;

    my %args = (
        LinkType  => undef,
        Direction => undef,
        Type   => undef,
	_found => {},
	_top   => 1,
        @_
    );

    my $dep = $self->_Links( $args{Direction}, $args{LinkType});
    while (my $link = $dep->Next()) {
        my $uri = $args{Direction} eq 'Target' ? $link->BaseURI : $link->TargetURI;
	next unless ($uri->IsLocal());
        my $obj = $args{Direction} eq 'Target' ? $link->BaseObj : $link->TargetObj;
	next if $args{_found}{$obj->Id};

	if (!$args{Type}) {
	    $args{_found}{$obj->Id} = $obj;
	    $obj->_AllLinkedTickets( %args, _top => 0 );
	}
	elsif ($obj->Type and $obj->Type eq $args{Type}) {
	    $args{_found}{$obj->Id} = $obj;
	}
	else {
	    $obj->_AllLinkedTickets( %args, _top => 0 );
	}
    }

    if ($args{_top}) {
	return map { $args{_found}{$_} } sort keys %{$args{_found}};
    }
    else {
	return 1;
    }
}



=head2 DependsOn

  This returns an RT::Links object which references all the tickets that this ticket depends on

=cut

sub DependsOn {
    my $self = shift;
    return ( $self->_Links( 'Base', 'DependsOn' ) );
}






=head2 Links DIRECTION [TYPE]

Return links (L<RT::Links>) to/from this object.

DIRECTION is either 'Base' or 'Target'.

TYPE is a type of links to return, it can be omitted to get
links of any type.

=cut

sub Links { shift->_Links(@_) }

sub _Links {
    my $self = shift;

    #TODO: Field isn't the right thing here. but I ahave no idea what mnemonic ---
    #tobias meant by $f
    my $field = shift;
    my $type  = shift || "";

    unless ( $self->{"$field$type"} ) {
        $self->{"$field$type"} = RT::Links->new( $self->CurrentUser );
            # at least to myself
            $self->{"$field$type"}->Limit( FIELD => $field,
                                           VALUE => $self->URI,
                                           ENTRYAGGREGATOR => 'OR' );
            $self->{"$field$type"}->Limit( FIELD => 'Type',
                                           VALUE => $type )
              if ($type);
    }
    return ( $self->{"$field$type"} );
}




=head2 FormatType

Takes a Type and returns a string that is more human readable.

=cut

sub FormatType{
    my $self = shift;
    my %args = ( Type => '',
		 @_
	       );
    $args{Type} =~ s/([A-Z])/" " . lc $1/ge;
    $args{Type} =~ s/^\s+//;
    return $args{Type};
}




=head2 FormatLink

Takes either a Target or a Base and returns a string of human friendly text.

=cut

sub FormatLink {
    my $self = shift;
    my %args = ( Object => undef,
		 FallBack => '',
		 @_
	       );
    my $text = "URI " . $args{FallBack};
    if ($args{Object} && $args{Object}->isa("RT::Ticket")) {
	$text = "Ticket " . $args{Object}->id;
    }
    return $text;
}

=head2 _AddLink

Takes a paramhash of Type and one of Base or Target. Adds that link to this object.

If Silent is true then no transactions will be recorded.  You can individually
control transactions on both base and target and with SilentBase and
SilentTarget respectively. By default both transactions are created.

Returns a tuple of (link ID, message, flag if link already existed).

=cut

sub _AddLink {
    my $self = shift;
    my %args = (
        Target       => '',
        Base         => '',
        Type         => '',
        Silent       => undef,
        Silent       => undef,
        SilentBase   => undef,
        SilentTarget => undef,
        @_
    );

    # Remote_link is the URI of the object that is not this ticket
    my $remote_link;
    my $direction;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug( "$self tried to create a link. both base and target were specified" );
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
        $remote_link    = $args{'Base'};
        $direction      = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
        $remote_link  = $args{'Target'};
        $direction    = 'Base';
    }
    else {
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    # Check if the link already exists - we don't want duplicates
    use RT::Link;
    my $old_link = RT::Link->new( $self->CurrentUser );
    $old_link->LoadByParams( Base   => $args{'Base'},
                             Type   => $args{'Type'},
                             Target => $args{'Target'} );
    if ( $old_link->Id ) {
        $RT::Logger->debug("$self Somebody tried to duplicate a link");
        return ( $old_link->id, $self->loc("Link already exists"), 1 );
    }

    # Storing the link in the DB.
    my $link = RT::Link->new( $self->CurrentUser );
    my ($linkid, $linkmsg) = $link->Create( Target => $args{Target},
                                            Base   => $args{Base},
                                            Type   => $args{Type} );

    unless ($linkid) {
        $RT::Logger->error("Link could not be created: ".$linkmsg);
        return ( 0, $self->loc("Link could not be created: [_1]", $linkmsg) );
    }

    my $basetext = $self->FormatLink(Object   => $link->BaseObj,
                                     FallBack => $args{Base});
    my $targettext = $self->FormatLink(Object   => $link->TargetObj,
                                       FallBack => $args{Target});
    my $typetext = $self->FormatType(Type => $args{Type});
    my $TransString = "$basetext $typetext $targettext.";

    # No transactions for you!
    return ($linkid, $TransString) if $args{'Silent'};

    # Some transactions?
    my $remote_uri = RT::URI->new( $self->CurrentUser );
    $remote_uri->FromURI( $remote_link );

    my $opposite_direction = $direction eq 'Target' ? 'Base': 'Target';

    unless ( $args{ 'Silent'. $direction } ) {
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'AddLink',
            Field     => $RT::Link::DIRMAP{$args{'Type'}}->{$direction},
            NewValue  => $remote_uri->URI || $remote_link,
            TimeTaken => 0
        );
        $RT::Logger->error("Couldn't create transaction: $Msg") unless $Trans;
    }

    if ( !$args{"Silent$opposite_direction"} && $remote_uri->IsLocal ) {
        my $OtherObj = $remote_uri->Object;
        my ( $val, $msg ) = $OtherObj->_NewTransaction(
            Type           => 'AddLink',
            Field          => $RT::Link::DIRMAP{$args{'Type'}}->{$opposite_direction},
            NewValue       => $self->URI,
            TimeTaken      => 0,
        );
        $RT::Logger->error("Couldn't create transaction: $msg") unless $val;
    }

    return ($linkid, $TransString);
}

=head2 _DeleteLink

Takes a paramhash of Type and one of Base or Target. Removes that link from this object.

If Silent is true then no transactions will be recorded.  You can individually
control transactions on both base and target and with SilentBase and
SilentTarget respectively. By default both transactions are created.

Returns a tuple of (status flag, message).

=cut 

sub _DeleteLink {
    my $self = shift;
    my %args = (
        Base         => undef,
        Target       => undef,
        Type         => undef,
        Silent       => undef,
        SilentBase   => undef,
        SilentTarget => undef,
        @_
    );

    # We want one of base and target. We don't care which but we only want _one_.
    my $direction;
    my $remote_link;

    if ( $args{'Base'} and $args{'Target'} ) {
        $RT::Logger->debug("$self ->_DeleteLink. got both Base and Target");
        return ( 0, $self->loc("Can't specifiy both base and target") );
    }
    elsif ( $args{'Base'} ) {
        $args{'Target'} = $self->URI();
        $remote_link    = $args{'Base'};
        $direction      = 'Target';
    }
    elsif ( $args{'Target'} ) {
        $args{'Base'} = $self->URI();
        $remote_link  = $args{'Target'};
        $direction    = 'Base';
    }
    else {
        $RT::Logger->error("Base or Target must be specified");
        return ( 0, $self->loc('Either base or target must be specified') );
    }

    my $link = RT::Link->new( $self->CurrentUser );
    $RT::Logger->debug( "Trying to load link: "
            . $args{'Base'} . " "
            . $args{'Type'} . " "
            . $args{'Target'} );

    $link->LoadByParams(
        Base   => $args{'Base'},
        Type   => $args{'Type'},
        Target => $args{'Target'}
    );

    unless ($link->id) {
        $RT::Logger->debug("Couldn't find that link");
        return ( 0, $self->loc("Link not found") );
    }

    my $basetext = $self->FormatLink(Object   => $link->BaseObj,
                                     FallBack => $args{Base});
    my $targettext = $self->FormatLink(Object   => $link->TargetObj,
                                       FallBack => $args{Target});
    my $typetext = $self->FormatType(Type => $args{Type});
    my $TransString = "$basetext no longer $typetext $targettext.";

    my ($ok, $msg) = $link->Delete();
    unless ($ok) {
        RT->Logger->error("Link could not be deleted: $msg");
        return ( 0, $self->loc("Link could not be deleted: [_1]", $msg) );
    }

    # No transactions for you!
    return (1, $TransString) if $args{'Silent'};

    # Some transactions?
    my $remote_uri = RT::URI->new( $self->CurrentUser );
    $remote_uri->FromURI( $remote_link );

    my $opposite_direction = $direction eq 'Target' ? 'Base': 'Target';

    unless ( $args{ 'Silent'. $direction } ) {
        my ( $Trans, $Msg, $TransObj ) = $self->_NewTransaction(
            Type      => 'DeleteLink',
            Field     => $RT::Link::DIRMAP{$args{'Type'}}->{$direction},
            OldValue  => $remote_uri->URI || $remote_link,
            TimeTaken => 0
        );
        $RT::Logger->error("Couldn't create transaction: $Msg") unless $Trans;
    }

    if ( !$args{"Silent$opposite_direction"} && $remote_uri->IsLocal ) {
        my $OtherObj = $remote_uri->Object;
        my ( $val, $msg ) = $OtherObj->_NewTransaction(
            Type           => 'DeleteLink',
            Field          => $RT::Link::DIRMAP{$args{'Type'}}->{$opposite_direction},
            OldValue       => $self->URI,
            TimeTaken      => 0,
        );
        $RT::Logger->error("Couldn't create transaction: $msg") unless $val;
    }

    return (1, $TransString);
}

=head1 LockForUpdate

In a database transaction, gains an exclusive lock on the row, to
prevent race conditions.  On SQLite, this is a "RESERVED" lock on the
entire database.

=cut

sub LockForUpdate {
    my $self = shift;

    my $pk = $self->_PrimaryKey;
    my $id = @_ ? $_[0] : $self->$pk;
    $self->_expire if $self->isa("DBIx::SearchBuilder::Record::Cachable");
    if (RT->Config->Get('DatabaseType') eq "SQLite") {
        # SQLite does DB-level locking, upgrading the transaction to
        # "RESERVED" on the first UPDATE/INSERT/DELETE.  Do a no-op
        # UPDATE to force the upgade.
        return RT->DatabaseHandle->dbh->do(
            "UPDATE " .$self->Table.
                " SET $pk = $pk WHERE 1 = 0");
    } else {
        return $self->_LoadFromSQL(
            "SELECT * FROM ".$self->Table
                ." WHERE $pk = ? FOR UPDATE",
            $id,
        );
    }
}

=head2 _NewTransaction  PARAMHASH

Private function to create a new RT::Transaction object for this ticket update

=cut

sub _NewTransaction {
    my $self = shift;
    my %args = (
        TimeTaken => undef,
        Type      => undef,
        OldValue  => undef,
        NewValue  => undef,
        OldReference  => undef,
        NewReference  => undef,
        ReferenceType => undef,
        Data      => undef,
        Field     => undef,
        MIMEObj   => undef,
        ActivateScrips => 1,
        CommitScrips => 1,
        SquelchMailTo => undef,
        @_
    );

    my $in_txn = RT->DatabaseHandle->TransactionDepth;
    RT->DatabaseHandle->BeginTransaction unless $in_txn;

    $self->LockForUpdate;

    my $old_ref = $args{'OldReference'};
    my $new_ref = $args{'NewReference'};
    my $ref_type = $args{'ReferenceType'};
    if ($old_ref or $new_ref) {
	$ref_type ||= ref($old_ref) || ref($new_ref);
	if (!$ref_type) {
	    $RT::Logger->error("Reference type not specified for transaction");
	    return;
	}
	$old_ref = $old_ref->Id if ref($old_ref);
	$new_ref = $new_ref->Id if ref($new_ref);
    }

    require RT::Transaction;
    my $trans = RT::Transaction->new( $self->CurrentUser );
    my ( $transaction, $msg ) = $trans->Create(
	ObjectId  => $self->Id,
	ObjectType => ref($self),
        TimeTaken => $args{'TimeTaken'},
        Type      => $args{'Type'},
        Data      => $args{'Data'},
        Field     => $args{'Field'},
        NewValue  => $args{'NewValue'},
        OldValue  => $args{'OldValue'},
        NewReference  => $new_ref,
        OldReference  => $old_ref,
        ReferenceType => $ref_type,
        MIMEObj   => $args{'MIMEObj'},
        ActivateScrips => $args{'ActivateScrips'},
        CommitScrips => $args{'CommitScrips'},
        SquelchMailTo => $args{'SquelchMailTo'},
    );

    # Rationalize the object since we may have done things to it during the caching.
    $self->Load($self->Id);

    $RT::Logger->warning($msg) unless $transaction;

    $self->_SetLastUpdated;

    if ( defined $args{'TimeTaken'} and $self->can('_UpdateTimeTaken')) {
        $self->_UpdateTimeTaken( $args{'TimeTaken'} );
    }
    if ( RT->Config->Get('UseTransactionBatch') and $transaction ) {
	    push @{$self->{_TransactionBatch}}, $trans if $args{'CommitScrips'};
    }

    RT->DatabaseHandle->Commit unless $in_txn;

    return ( $transaction, $msg, $trans );
}



=head2 Transactions

Returns an L<RT::Transactions> object of all transactions on this record object

=cut

sub Transactions {
    my $self = shift;

    use RT::Transactions;
    my $transactions = RT::Transactions->new( $self->CurrentUser );
    $transactions->Limit(
        FIELD => 'ObjectId',
        VALUE => $self->id,
    );
    $transactions->Limit(
        FIELD => 'ObjectType',
        VALUE => ref($self),
    );

    return $transactions;
}

=head2 SortedTransactions

Returns the result of L</Transactions> ordered per the
I<OldestTransactionsFirst> preference/option.

=cut

sub SortedTransactions {
    my $self  = shift;
    my $txns  = $self->Transactions;
    my $order = RT->Config->Get("OldestTransactionsFirst", $self->CurrentUser)
        ? 'ASC' : 'DESC';
    $txns->OrderByCols(
        { FIELD => 'Created',   ORDER => $order },
        { FIELD => 'id',        ORDER => $order },
    );
    return $txns;
}

our %TRANSACTION_CLASSIFICATION = (
    Create     => 'message',
    Correspond => 'message',
    Comment    => 'message',

    AddWatcher => 'people',
    DelWatcher => 'people',

    Take       => 'people',
    Untake     => 'people',
    Force      => 'people',
    Steal      => 'people',
    Give       => 'people',

    AddLink    => 'links',
    DeleteLink => 'links',

    Status     => 'basics',
    Set        => {
        __default => 'basics',
        map( { $_ => 'dates' } qw(
            Told Starts Started Due LastUpdated Created LastUpdated
        ) ),
        map( { $_ => 'people' } qw(
            Owner Creator LastUpdatedBy
        ) ),
    },
    __default => 'other',
);

sub ClassifyTransaction {
    my $self = shift;
    my $txn = shift;

    my $type = $txn->Type;

    my $res = $TRANSACTION_CLASSIFICATION{ $type };
    return $res || $TRANSACTION_CLASSIFICATION{ '__default' }
        unless ref $res;

    return $res->{ $txn->Field } || $res->{'__default'}
        || $TRANSACTION_CLASSIFICATION{ '__default' }; 
}

=head2 Attachments

Returns an L<RT::Attachments> object of all attachments on this record object
(for all its L</Transactions>).

By default Content and Headers of attachments are not fetched right away from
database. Use C<WithContent> and C<WithHeaders> options to override this.

=cut

sub Attachments {
    my $self = shift;
    my %args = (
        WithHeaders => 0,
        WithContent => 0,
        @_
    );
    my @columns = grep { not /^(Headers|Content)$/ }
                       RT::Attachment->ReadableAttributes;
    push @columns, 'Headers' if $args{'WithHeaders'};
    push @columns, 'Content' if $args{'WithContent'};

    my $res = RT::Attachments->new( $self->CurrentUser );
    $res->Columns( @columns );
    my $txn_alias = $res->TransactionAlias;
    $res->Limit(
        ALIAS => $txn_alias,
        FIELD => 'ObjectType',
        VALUE => ref($self),
    );
    $res->Limit(
        ALIAS => $txn_alias,
        FIELD => 'ObjectId',
        VALUE => $self->id,
    );
    return $res;
}

=head2 TextAttachments

Returns an L<RT::Attachments> object of all attachments, like L<Attachments>,
but only those that are text.

By default Content and Headers are fetched. Use C<WithContent> and
C<WithHeaders> options to override this.

=cut

sub TextAttachments {
    my $self = shift;
    my $res = $self->Attachments(
        WithHeaders => 1,
        WithContent => 1,
        @_
    );
    $res->Limit( FIELD => 'ContentType', OPERATOR => '=', VALUE => 'text/plain');
    $res->Limit( FIELD => 'ContentType', OPERATOR => 'STARTSWITH', VALUE => 'message/');
    $res->Limit( FIELD => 'ContentType', OPERATOR => '=', VALUE => 'text');
    $res->Limit( FIELD => 'Filename', OPERATOR => 'IS', VALUE => 'NULL')
        if RT->Config->Get( 'SuppressInlineTextFiles', $self->CurrentUser );
    return $res;
}

sub CustomFields {
    my $self = shift;
    my $cfs  = RT::CustomFields->new( $self->CurrentUser );
    
    $cfs->SetContextObject( $self );
    # XXX handle multiple types properly
    $cfs->LimitToLookupType( $self->CustomFieldLookupType );
    $cfs->LimitToGlobalOrObjectId( $self->CustomFieldLookupId );
    $cfs->ApplySortOrder;

    return $cfs;
}

# TODO: This _only_ works for RT::Foo classes. it doesn't work, for
# example, for RT::IR::Foo classes.

sub CustomFieldLookupId {
    my $self = shift;
    my $lookup = shift || $self->CustomFieldLookupType;
    my @classes = ($lookup =~ /RT::(\w+)-/g);

    # Work on "RT::Queue", for instance
    return $self->Id unless @classes;

    my $object = $self;
    # Save a ->Load call by not calling ->FooObj->Id, just ->Foo
    my $final = shift @classes;
    foreach my $class (reverse @classes) {
	my $method = "${class}Obj";
	$object = $object->$method;
    }

    return $object->$final;
}


=head2 CustomFieldLookupType 

Returns the path RT uses to figure out which custom fields apply to this object.

=cut

sub CustomFieldLookupType {
    my $self = shift;
    return ref($self);
}


=head2 AddCustomFieldValue { Field => FIELD, Value => VALUE }

VALUE should be a string. FIELD can be any identifier of a CustomField
supported by L</LoadCustomFieldByIdentifier> method.

Adds VALUE as a value of CustomField FIELD. If this is a single-value custom field,
deletes the old value.
If VALUE is not a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns ($id, 'Success Message') where
$id is ID of created L<ObjectCustomFieldValue> object.

=cut

sub AddCustomFieldValue {
    my $self = shift;
    $self->_AddCustomFieldValue(@_);
}

sub _AddCustomFieldValue {
    my $self = shift;
    my %args = (
        Field             => undef,
        Value             => undef,
        LargeContent      => undef,
        ContentType       => undef,
        RecordTransaction => 1,
        @_
    );

    my $cf = $self->LoadCustomFieldByIdentifier($args{'Field'});
    unless ( $cf->Id ) {
        return ( 0, $self->loc( "Custom field [_1] not found", $args{'Field'} ) );
    }

    my $OCFs = $self->CustomFields;
    $OCFs->Limit( FIELD => 'id', VALUE => $cf->Id );
    unless ( $OCFs->Count ) {
        return (
            0,
            $self->loc(
                "Custom field [_1] does not apply to this object",
                ref $args{'Field'} ? $args{'Field'}->id : $args{'Field'}
            )
        );
    }

    # empty string is not correct value of any CF, so undef it
    foreach ( qw(Value LargeContent) ) {
        $args{ $_ } = undef if defined $args{ $_ } && !length $args{ $_ };
    }

    unless ( $cf->ValidateValue( $args{'Value'} ) ) {
        return ( 0, $self->loc("Invalid value for custom field") );
    }

    # If the custom field only accepts a certain # of values, delete the existing
    # value and record a "changed from foo to bar" transaction
    unless ( $cf->UnlimitedValues ) {

        # Load up a ObjectCustomFieldValues object for this custom field and this ticket
        my $values = $cf->ValuesForObject($self);

        # We need to whack any old values here.  In most cases, the custom field should
        # only have one value to delete.  In the pathalogical case, this custom field
        # used to be a multiple and we have many values to whack....
        my $cf_values = $values->Count;

        if ( $cf_values > $cf->MaxValues ) {
            my $i = 0;   #We want to delete all but the max we can currently have , so we can then
                 # execute the same code to "change" the value from old to new
            while ( my $value = $values->Next ) {
                $i++;
                if ( $i < $cf_values ) {
                    my ( $val, $msg ) = $cf->DeleteValueForObject(
                        Object  => $self,
                        Content => $value->Content
                    );
                    unless ($val) {
                        return ( 0, $msg );
                    }
                    my ( $TransactionId, $Msg, $TransactionObj ) =
                      $self->_NewTransaction(
                        Type         => 'CustomField',
                        Field        => $cf->Id,
                        OldReference => $value,
                      );
                }
            }
            $values->RedoSearch if $i; # redo search if have deleted at least one value
        }

        my ( $old_value, $old_content );
        if ( $old_value = $values->First ) {
            $old_content = $old_value->Content;
            $old_content = undef if defined $old_content && !length $old_content;

            my $is_the_same = 1;
            if ( defined $args{'Value'} ) {
                $is_the_same = 0 unless defined $old_content
                    && lc $old_content eq lc $args{'Value'};
            } else {
                $is_the_same = 0 if defined $old_content;
            }
            if ( $is_the_same ) {
                my $old_content = $old_value->LargeContent;
                if ( defined $args{'LargeContent'} ) {
                    $is_the_same = 0 unless defined $old_content
                        && $old_content eq $args{'LargeContent'};
                } else {
                    $is_the_same = 0 if defined $old_content;
                }
            }

            return $old_value->id if $is_the_same;
        }

        my ( $new_value_id, $value_msg ) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
        );

        unless ( $new_value_id ) {
            return ( 0, $self->loc( "Could not add new custom field value: [_1]", $value_msg ) );
        }

        my $new_value = RT::ObjectCustomFieldValue->new( $self->CurrentUser );
        $new_value->Load( $new_value_id );

        # now that adding the new value was successful, delete the old one
        if ( $old_value ) {
            my ( $val, $msg ) = $old_value->Delete();
            return ( 0, $msg ) unless $val;
        }

        if ( $args{'RecordTransaction'} ) {
            my ( $TransactionId, $Msg, $TransactionObj ) =
              $self->_NewTransaction(
                Type         => 'CustomField',
                Field        => $cf->Id,
                OldReference => $old_value,
                NewReference => $new_value,
              );
        }

        my $new_content = $new_value->Content;

        # For datetime, we need to display them in "human" format in result message
        #XXX TODO how about date without time?
        if ($cf->Type eq 'DateTime') {
            my $DateObj = RT::Date->new( $self->CurrentUser );
            $DateObj->Set(
                Format => 'ISO',
                Value  => $new_content,
            );
            $new_content = $DateObj->AsString;

            if ( defined $old_content && length $old_content ) {
                $DateObj->Set(
                    Format => 'ISO',
                    Value  => $old_content,
                );
                $old_content = $DateObj->AsString;
            }
        }

        unless ( defined $old_content && length $old_content ) {
            return ( $new_value_id, $self->loc( "[_1] [_2] added", $cf->Name, $new_content ));
        }
        elsif ( !defined $new_content || !length $new_content ) {
            return ( $new_value_id,
                $self->loc( "[_1] [_2] deleted", $cf->Name, $old_content ) );
        }
        else {
            return ( $new_value_id, $self->loc( "[_1] [_2] changed to [_3]", $cf->Name, $old_content, $new_content));
        }

    }

    # otherwise, just add a new value and record "new value added"
    else {
        my ($new_value_id, $msg) = $cf->AddValueForObject(
            Object       => $self,
            Content      => $args{'Value'},
            LargeContent => $args{'LargeContent'},
            ContentType  => $args{'ContentType'},
        );

        unless ( $new_value_id ) {
            return ( 0, $self->loc( "Could not add new custom field value: [_1]", $msg ) );
        }
        if ( $args{'RecordTransaction'} ) {
            my ( $tid, $msg ) = $self->_NewTransaction(
                Type          => 'CustomField',
                Field         => $cf->Id,
                NewReference  => $new_value_id,
                ReferenceType => 'RT::ObjectCustomFieldValue',
            );
            unless ( $tid ) {
                return ( 0, $self->loc( "Couldn't create a transaction: [_1]", $msg ) );
            }
        }
        return ( $new_value_id, $self->loc( "[_1] added as a value for [_2]", $args{'Value'}, $cf->Name ) );
    }
}



=head2 DeleteCustomFieldValue { Field => FIELD, Value => VALUE }

Deletes VALUE as a value of CustomField FIELD. 

VALUE can be a string, a CustomFieldValue or a ObjectCustomFieldValue.

If VALUE is not a valid value for the custom field, returns 
(0, 'Error message' ) otherwise, returns (1, 'Success Message')

=cut

sub DeleteCustomFieldValue {
    my $self = shift;
    my %args = (
        Field   => undef,
        Value   => undef,
        ValueId => undef,
        @_
    );

    my $cf = $self->LoadCustomFieldByIdentifier($args{'Field'});
    unless ( $cf->Id ) {
        return ( 0, $self->loc( "Custom field [_1] not found", $args{'Field'} ) );
    }

    my ( $val, $msg ) = $cf->DeleteValueForObject(
        Object  => $self,
        Id      => $args{'ValueId'},
        Content => $args{'Value'},
    );
    unless ($val) {
        return ( 0, $msg );
    }

    my ( $TransactionId, $Msg, $TransactionObj ) = $self->_NewTransaction(
        Type          => 'CustomField',
        Field         => $cf->Id,
        OldReference  => $val,
        ReferenceType => 'RT::ObjectCustomFieldValue',
    );
    unless ($TransactionId) {
        return ( 0, $self->loc( "Couldn't create a transaction: [_1]", $Msg ) );
    }

    my $old_value = $TransactionObj->OldValue;
    # For datetime, we need to display them in "human" format in result message
    if ( $cf->Type eq 'DateTime' ) {
        my $DateObj = RT::Date->new( $self->CurrentUser );
        $DateObj->Set(
            Format => 'ISO',
            Value  => $old_value,
        );
        $old_value = $DateObj->AsString;
    }
    return (
        $TransactionId,
        $self->loc(
            "[_1] is no longer a value for custom field [_2]",
            $old_value, $cf->Name
        )
    );
}



=head2 FirstCustomFieldValue FIELD

Return the content of the first value of CustomField FIELD for this ticket
Takes a field id or name

=cut

sub FirstCustomFieldValue {
    my $self = shift;
    my $field = shift;

    my $values = $self->CustomFieldValues( $field );
    return undef unless my $first = $values->First;
    return $first->Content;
}

=head2 CustomFieldValuesAsString FIELD

Return the content of the CustomField FIELD for this ticket.
If this is a multi-value custom field, values will be joined with newlines.

Takes a field id or name as the first argument

Takes an optional Separator => "," second and third argument
if you want to join the values using something other than a newline

=cut

sub CustomFieldValuesAsString {
    my $self  = shift;
    my $field = shift;
    my %args  = @_;
    my $separator = $args{Separator} || "\n";

    my $values = $self->CustomFieldValues( $field );
    return join ($separator, grep { defined $_ }
                 map { $_->Content } @{$values->ItemsArrayRef});
}



=head2 CustomFieldValues FIELD

Return a ObjectCustomFieldValues object of all values of the CustomField whose 
id or Name is FIELD for this record.

Returns an RT::ObjectCustomFieldValues object

=cut

sub CustomFieldValues {
    my $self  = shift;
    my $field = shift;

    if ( $field ) {
        my $cf = $self->LoadCustomFieldByIdentifier( $field );

        # we were asked to search on a custom field we couldn't find
        unless ( $cf->id ) {
            $RT::Logger->warning("Couldn't load custom field by '$field' identifier");
            return RT::ObjectCustomFieldValues->new( $self->CurrentUser );
        }
        return ( $cf->ValuesForObject($self) );
    }

    # we're not limiting to a specific custom field;
    my $ocfs = RT::ObjectCustomFieldValues->new( $self->CurrentUser );
    $ocfs->LimitToObject( $self );
    return $ocfs;
}

=head2 LoadCustomFieldByIdentifier IDENTIFER

Find the custom field has id or name IDENTIFIER for this object.

If no valid field is found, returns an empty RT::CustomField object.

=cut

sub LoadCustomFieldByIdentifier {
    my $self = shift;
    my $field = shift;
    
    my $cf;
    if ( UNIVERSAL::isa( $field, "RT::CustomField" ) ) {
        $cf = RT::CustomField->new($self->CurrentUser);
        $cf->SetContextObject( $self );
        $cf->LoadById( $field->id );
    }
    elsif ($field =~ /^\d+$/) {
        $cf = RT::CustomField->new($self->CurrentUser);
        $cf->SetContextObject( $self );
        $cf->LoadById($field);
    } else {

        my $cfs = $self->CustomFields($self->CurrentUser);
        $cfs->SetContextObject( $self );
        $cfs->Limit(FIELD => 'Name', VALUE => $field, CASESENSITIVE => 0);
        $cf = $cfs->First || RT::CustomField->new($self->CurrentUser);
    }
    return $cf;
}

sub ACLEquivalenceObjects { } 

sub BasicColumns { }

sub WikiBase {
    return RT->Config->Get('WebPath'). "/index.html?q=";
}

=head2 RegisterRole

Registers an RT role which applies to this class for role-based access control.
Arguments:

=over 4

=item Name

Required.  The role name (i.e. Requestor, Owner, AdminCc, etc).

=item EquivClasses

Optional.  Array ref of classes through which this role percolates up to
L<RT::System>.  You can think of this list as:

    map { ref } $record_object->ACLEquivalenceObjects;

You should not include L<RT::System> itself in this list.

Simply calls RegisterRole on each equivalent class.

=back

=cut

sub RegisterRole {
    my $self  = shift;
    my $class = ref($self) || $self;
    my %role  = (
        Name            => undef,
        EquivClasses    => [],
        @_
    );
    return unless $role{Name};

    # Keep track of the class this role came from originally
    $role{ Class } ||= $class;

    # Some groups are limited to a single user
    $role{ Single } = 1 if $role{Column};

    # Stash the role on ourself
    $class->_ROLES->{ $role{Name} } = \%role;

    # Register it with any equivalent classes...
    my $equiv = delete $role{EquivClasses} || [];

    # ... and globally unless we ARE global
    unless ($class eq "RT::System") {
        require RT::System;
        push @$equiv, "RT::System";
    }

    $_->RegisterRole(%role) for @$equiv;

    # XXX TODO: Register which classes have roles on them somewhere?

    return 1;
}

=head2 Roles

Returns a list of role names registered for this class.

=cut

sub Roles { sort { $a cmp $b } keys %{ shift->_ROLES } }

{
    my %ROLES;
    sub _ROLES {
        my $class = ref($_[0]) || $_[0];
        return $ROLES{$class} ||= {};
    }
}

=head2 HasRole

Returns true if the name provided is a registered role for this class.
Otherwise returns false.

=cut

sub HasRole {
    my $self = shift;
    my $type = shift;
    return scalar grep { $type eq $_ } $self->Roles;
}

=head2 RoleGroup

Expects a role name as the first parameter which is used to load the
L<RT::Group> for the specified role on this record.  Returns an unloaded
L<RT::Group> object on failure.

=cut

sub RoleGroup {
    my $self  = shift;
    my $type  = shift;
    my $group = RT::Group->new( $self->CurrentUser );

    if ($self->HasRole($type)) {
        $group->LoadRoleGroup(
            Object  => $self,
            Type    => $type,
        );
    }
    return $group;
}

=head2 AddRoleMember

Adds the described L<RT::Principal> to the specified role group for this record.

Takes a set of key-value pairs:

=over 4

=item PrincipalId

Optional.  The ID of the L<RT::Principal> object to add.

=item User

Optional.  The Name or EmailAddress of an L<RT::User> to use as the
principal.  If an email address is given, but a user matching it cannot
be found, a new user will be created.

=item Group

Optional.  The Name of an L<RT::Group> to use as the principal.

=item Type

Required.  One of the valid roles for this record, as returned by L</Roles>.

=item ACL

Optional.  A subroutine reference which will be passed the role type and
principal being added.  If it returns false, the method will fail with a
status of "Permission denied".

=back

One, and only one, of I<PrincipalId>, I<User>, or I<Group> is required.

Returns a tuple of (principal object which was added, message).

=cut

sub AddRoleMember {
    my $self = shift;
    my %args = (@_);

    return (0, $self->loc("One, and only one, of PrincipalId/User/Group is required"))
        if 1 != grep { $_ } @args{qw/PrincipalId User Group/};

    my $type = delete $args{Type};
    return (0, $self->loc("No valid Type specified"))
        unless $type and $self->HasRole($type);

    if ($args{PrincipalId}) {
        # Check the PrincipalId for loops
        my $principal = RT::Principal->new( $self->CurrentUser );
        $principal->Load($args{'PrincipalId'});
        if ( $principal->id and $principal->IsUser and my $email = $principal->Object->EmailAddress ) {
            return (0, $self->loc("[_1] is an address RT receives mail at. Adding it as a '[_2]' would create a mail loop",
                                  $email, $self->loc($type)))
                if RT::EmailParser->IsRTAddress( $email );
        }
    } else {
        if ($args{User}) {
            my $name = delete $args{User};
            # Sanity check the address
            return (0, $self->loc("[_1] is an address RT receives mail at. Adding it as a '[_2]' would create a mail loop",
                                  $name, $self->loc($type) ))
                if RT::EmailParser->IsRTAddress( $name );

            # Create as the SystemUser, not the current user
            my $user = RT::User->new(RT->SystemUser);
            my ($pid, $msg) = $user->LoadOrCreateByEmail( $name );
            unless ($pid) {
                # If we can't find this watcher, we need to bail.
                $RT::Logger->error("Could not load or create a user '$name' to add as a watcher: $msg");
                return (0, $self->loc("Could not find or create user '$name'"));
            }
            $args{PrincipalId} = $pid;
        }
        elsif ($args{Group}) {
            my $name = delete $args{Group};
            my $group = RT::Group->new( $self->CurrentUser );
            $group->LoadUserDefinedGroup($name);
            unless ($group->id) {
                $RT::Logger->error("Could not load group '$name' to add as a watcher");
                return (0, $self->loc("Could not find group '$name'"));
            }
            $args{PrincipalId} = $group->PrincipalObj->id;
        }
    }

    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $args{PrincipalId} );

    my $acl = delete $args{ACL};
    return (0, $self->loc("Permission denied"))
        if $acl and not $acl->($type => $principal);

    my $group = $self->RoleGroup( $type );
    return (0, $self->loc("Role group '$type' not found"))
        unless $group->id;

    return (0, $self->loc('[_1] is already a [_2]',
                          $principal->Object->Name, $self->loc($type)) )
            if $group->HasMember( $principal );

    my ( $ok, $msg ) = $group->_AddMember( %args );
    unless ($ok) {
        $RT::Logger->error("Failed to add $args{PrincipalId} as a member of group ".$group->Id.": ".$msg);

        return ( 0, $self->loc('Could not make [_1] a [_2]',
                    $principal->Object->Name, $self->loc($type)) );
    }

    unless ($args{Silent}) {
        $self->_NewTransaction(
            Type     => 'AddWatcher', # use "watcher" for history's sake
            NewValue => $args{PrincipalId},
            Field    => $type,
        );
    }

    return ($principal, $msg);
}

=head2 DeleteRoleMember

Removes the specified L<RT::Principal> from the specified role group for this
record.

Takes a set of key-value pairs:

=over 4

=item PrincipalId

Optional.  The ID of the L<RT::Principal> object to remove.

=item User

Optional.  The Name or EmailAddress of an L<RT::User> to use as the
principal

=item Type

Required.  One of the valid roles for this record, as returned by L</Roles>.

=back

One, and only one, of I<PrincipalId> or I<User> is required.

Returns a tuple of (principal object that was removed, message).

=cut

sub DeleteRoleMember {
    my $self = shift;
    my %args = (@_);

    return (0, $self->loc("No valid Type specified"))
        unless $args{Type} and $self->HasRole($args{Type});

    if ($args{User}) {
        my $user = RT::User->new( $self->CurrentUser );
        $user->LoadByEmail( $args{User} );
        $user->Load( $args{User} ) unless $user->id;
        return (0, $self->loc("Could not load user '$args{User}'") )
            unless $user->id;
        $args{PrincipalId} = $user->PrincipalId;
    }

    return (0, $self->loc("No valid PrincipalId"))
        unless $args{PrincipalId};

    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $args{PrincipalId} );

    my $acl = delete $args{ACL};
    return (0, $self->loc("Permission denied"))
        if $acl and not $acl->($principal);

    my $group = $self->RoleGroup( $args{Type} );
    return (0, $self->loc("Role group '$args{Type}' not found"))
        unless $group->id;

    return ( 0, $self->loc( '[_1] is not a [_2]',
                            $principal->Object->Name, $self->loc($args{Type}) ) )
        unless $group->HasMember($principal);

    my ($ok, $msg) = $group->_DeleteMember($args{PrincipalId});
    unless ($ok) {
        $RT::Logger->error("Failed to remove $args{PrincipalId} as a member of group ".$group->Id.": ".$msg);

        return ( 0, $self->loc('Could not remove [_1] as a [_2]',
                    $principal->Object->Name, $self->loc($args{Type})) );
    }

    unless ($args{Silent}) {
        $self->_NewTransaction(
            Type     => 'DelWatcher', # use "watcher" for history's sake
            OldValue => $args{PrincipalId},
            Field    => $args{Type},
        );
    }
    return ($principal, $msg);
}

sub _ResolveRoles {
    my $self = shift;
    my ($roles, %args) = (@_);

    my @errors;
    for my $role ($self->Roles) {
        if ($self->_ROLES->{$role}{Single}) {
            # Default to nobody if unspecified
            my $value = $args{$role} || RT->Nobody;
            if (Scalar::Util::blessed($value) and $value->isa("RT::User")) {
                # Accept a user; it may not be loaded, which we catch below
                $roles->{$role} = $value->PrincipalObj;
            } else {
                # Try loading by id, name, then email.  If all fail, catch that below
                my $user = RT::User->new( $self->CurrentUser );
                $user->Load( $value );
                # XXX: LoadOrCreateByEmail ?
                $user->LoadByEmail( $value ) unless $user->id;
                $roles->{$role} = $user->PrincipalObj;
            }
            unless ($roles->{$role}->id) {
                push @errors, $self->loc("Invalid value for [_1]",loc($role));
                $roles->{$role} = RT->Nobody->PrincipalObj unless $roles->{$role}->id;
            }
            # For consistency, we always return an arrayref
            $roles->{$role} = [ $roles->{$role} ];
        } else {
            $roles->{$role} = [];
            my @values = ref $args{ $role } ? @{ $args{$role} } : ($args{$role});
            for my $value (grep {defined} @values) {
                if ( $value =~ /^\d+$/ ) {
                    # This implicitly allows groups, if passed by id.
                    my $principal = RT::Principal->new( $self->CurrentUser );
                    my ($ok, $msg) = $principal->Load( $value );
                    if ($ok) {
                        push @{ $roles->{$role} }, $principal;
                    } else {
                        push @errors,
                            $self->loc("Couldn't load principal: [_1]", $msg);
                    }
                } else {
                    my @addresses = RT::EmailParser->ParseEmailAddress( $value );
                    for my $address ( @addresses ) {
                        my $user = RT::User->new( RT->SystemUser );
                        my ($id, $msg) = $user->LoadOrCreateByEmail( $address );
                        if ( $id ) {
                            # Load it back as us, not as the system
                            # user, to be completely safe.
                            $user = RT::User->new( $self->CurrentUser );
                            $user->Load( $id );
                            push @{ $roles->{$role} }, $user->PrincipalObj;
                        } else {
                            push @errors,
                                $self->loc("Couldn't load or create user: [_1]", $msg);
                        }
                    }
                }
            }
        }
    }
    return (@errors);
}

sub _CreateRoleGroups {
    my $self = shift;
    my %args = (@_);
    for my $type ($self->Roles) {
        my $type_obj = RT::Group->new($self->CurrentUser);
        my ($id, $msg) = $type_obj->CreateRoleGroup(
            Type    => $type,
            Object  => $self,
            %args,
        );
        unless ($id) {
            $RT::Logger->error("Couldn't create a role group of type '$type' for ".ref($self)." ".
                                   $self->Id.": ".$msg);
            return(undef);
        }
    }
    return(1);
}

sub _AddRolesOnCreate {
    my $self = shift;
    my ($roles, %acls) = @_;

    my @errors;
    {
        my $changed = 0;

        for my $role (keys %{$roles}) {
            my $group = $self->RoleGroup($role);
            my @left;
            for my $principal (@{$roles->{$role}}) {
                if ($acls{$role}->($principal)) {
                    next if $group->HasMember($principal);
                    my ($ok, $msg) = $group->_AddMember(
                        PrincipalId       => $principal->id,
                        InsideTransaction => 1,
                        RecordTransaction => 0,
                        Object            => $self,
                    );
                    push @errors, $self->loc("Couldn't set [_1] watcher: [_2]", $role, $msg)
                        unless $ok;
                    $changed++;
                } else {
                    push @left, $principal;
                }
            }
            $roles->{$role} = [ @left ];
        }

        redo if $changed;
    }

    return @errors;
}

RT::Base->_ImportOverlays();

1;
