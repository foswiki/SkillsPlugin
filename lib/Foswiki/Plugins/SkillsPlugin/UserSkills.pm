# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 - 2009 Andrew Jones, andrewjones86@googlemail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::SkillsPlugin::UserSkills;

use strict;

require Foswiki::Plugins::SkillsPlugin::UserSkill;

my %_userSkills;    # contains an array of UserSkill objects keyed by user

# Object that handles interaction with the user data (currently stored in the meta or the users topic)
sub new {

    my $class = shift;

    #my ($class, $name, $cat, $rating, $comment) = @_;

    my $self = bless( {}, $class );

    return $self;
}

# loads the skills for a particular user
# gets it from the meta of the topic and stores in global hash
sub _loadUserSkills {
    my $self = shift;

    my $user = shift;

    my $mainWeb = Foswiki::Func::getMainWebname();

    my ( $meta, undef ) = Foswiki::Func::readTopic( $mainWeb, $user );
    my @skillsMeta = $meta->find('SKILLS');
    my $userSkills = new Foswiki::Plugins::SkillsPlugin::UserSkill( $user );
    for my $skillMeta (@skillsMeta) {
        my $skill = new Foswiki::Plugins::SkillsPlugin::UserSkill(
            $skillMeta->{name});
        $skill->{rating} = $skillMeta->{rating} || -1;
        $skill->{text} = $skillMeta->{comment} || '';

        my @path = split('/', $skillMeta->{category});
        $userSkills->addByPath($skill, @path);
    }

    $_userSkills{$user} = $userSkills;
}

sub getUser {
    my ($this, $user) = @_;
    if (!$_userSkills{$user}) {
        $this->_loadUserSkills($user);
    }
    return $_userSkills{$user};
}

# gets the particular skill for a particular user. Returns undef if skill not set
#sub getSkillForUser {
#    my $self = shift;
#
#    my ( $user, $skill, $cat ) = @_;
#
#    $self->_loadUserSkills($user) unless $_userSkills{$user};
#
#    my $it = $self->eachUserSkill($user);
#    return undef unless $it;
#    while ( $it->hasNext() ) {
#        my $obj_userSkill = $it->next();
#        if (   $cat
#            && $obj_userSkill->category
#            && $cat eq $obj_userSkill->category
#            && $skill
#            && $obj_userSkill->name
#            && $skill eq $obj_userSkill->name )
#        {
#            return $obj_userSkill;
#        }
#    }
#    return undef;
#}

# returns all the users skills in array of UserSkill objects
#sub getUserSkills {
#    my $self = shift;
#
#    my $user = shift || return undef;
#
#    $self->_loadUserSkills($user) unless $_userSkills{$user};
#
#    return ( $_userSkills{$user} );
#}

# iterate over each of the skills for a particular user
#sub eachUserSkill {
#    my $self = shift;
#
#    my $user = shift;
#    return undef unless $user;
#
#    $self->_loadUserSkills($user) unless $_userSkills{$user};
#
#    require Foswiki::ListIterator;
#    return new Foswiki::ListIterator( $_userSkills{$user} );
#}

# returns all the users with the particular skill
#sub getUsersForSkill {
#    my $self = shift;
#
#    my ( $skill, $cat ) = @_;
#
#    my %usersWithSkill;
#
#    my $users = Foswiki::Func::eachUser();
#    while ( $users->hasNext() ) {
#        my $user = $users->next();
#
#        if ( my $obj_userSkill = $self->userHasSkill( $user, $skill, $cat ) ) {
#            $usersWithSkill{$user} = $obj_userSkill;
#        }
#    }
#
#    return \%usersWithSkill;
#}

# returns the user skill obj if user has the skill
# undef if not
#sub userHasSkill {
#    my $self = shift;
#
#    my ( $user, $skill, $cat ) = @_;
#
#    # all skills for this user
#    my $userSkills = $self->eachUserSkill($user);
#    while ( $userSkills->hasNext() ) {
#        my $obj_userSkill = $userSkills->next();
#
## trying to stop the 'Use of uninitialized value in string' warnings in Apache log file
#        if (   $cat
#            && $obj_userSkill->category
#            && $cat eq $obj_userSkill->category
#            && $skill
#            && $obj_userSkill->name
#            && $skill eq $obj_userSkill->name )
#        {
#            return $obj_userSkill;
#        }
#    }
#
#    return undef;
#}

# saves the skills for a particular user
sub save {
    my ($self, $user) = @_;

    my $mainWeb = Foswiki::Func::getMainWebname();

    my ( $meta, $text ) = Foswiki::Func::readTopic( $mainWeb, $user->{name} );

    $meta->remove('SKILLS');
    $user->saveToMeta($meta);

    Foswiki::Func::saveTopic(
        $meta->web(), $meta->topic(), $meta, $text,
        { dontlog => 1, comment => 'SkillsPlugin', minor => 1 } );
}

1;
