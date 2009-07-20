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

package Foswiki::Plugins::SkillsPlugin::SkillsStore;

use strict;

require Foswiki::Plugins::SkillsPlugin::Category;

my @_categories;
my $_loaded = 0;

# Object that handles interaction with the skills data (currently stored in a plain text file in the work area)
sub new {
    my $class = shift;

    my $self = {};

    return bless( $self, $class );
}

# Deprecated: read skills from file in work area
sub _getSkillsFromWorking {
    my $file = Foswiki::Func::getWorkArea('SkillsPlugin') . '/skills.txt';

    _Debug('reading skills.txt - ' . $file);

    my $fh;
    unless( open( $fh, '<', $file ) ) {
        # file could not be opened
        _Debug('skills.txt can not be opened. Maybe it does not exist?');
        return 1;
    }

    local $/ = "\n";

    while ( my $line = <$fh> ) {

        next if $line =~ /^\#.*/;    # skip any comments

        chomp($line);
        $line =~ s/(.*)://g;
        my $cat = $1;
        my @skills = split( ',', $line );

        my $obj_cat =
          Foswiki::Plugins::SkillsPlugin::Category->new( $cat, \@skills );
        push @_categories, $obj_cat;
    }

    close( $fh );
}

# loads the categories and skills from the topic (or file)
sub _load {
    my $self = shift;

    my $topic = Foswiki::Func::getPreferencesValue('SKILLSPLUGIN_SKILLSTOPIC');

    if (!$topic) {
        _getSkillsFromWorking();
    } else {

        (my $web, $topic) = Foswiki::Func::normalizeWebTopicName(
            undef, $topic);

        if (!Foswiki::Func::topicExists($web, $topic)) {
            print STDERR "Cannot find SKILLSPLUGIN_SKILLSTOPIC $web.$topic";
            _getSkillsFromWorking();
        }
        my ($meta, $text) = Foswiki::Func::readTopic( $web, $topic );
        unless (Foswiki::Func::checkAccessPermission(
            'VIEW', Foswiki::Func::getWikiName(),
            $text, $topic, $web, $meta )) {
            die "Cannot view SKILLSPLUGIN_SKILLSTOPIC $web.$topic";
        }

        my (@cats, %skills, %catdescs, %skilldescs);
        my ($cat, $skill);

        foreach my $line (split(/\r?\n/, $text)) {

            #   * Category
            #     Description
            #      * Skill
            #        Description
            if ($cat && $line =~ /^---\+\+\s*(.*)$/) {
                $skill = $1;
                push(@{$skills{$cat}}, $skill)
                  unless defined $skilldescs{$cat}->{$skill};
                $skilldescs{$cat}->{$skill} = '';
            } elsif ($line =~ /^---\+\s*(.*)$/) {
                $cat = $1;
                push(@cats, $cat) unless defined $catdescs{$cat};
                $skill = '';
                $catdescs{$cat} = '';
                $skilldescs{$cat} = {};
            } elsif ($cat && $skill && $line =~ /^\s*(\S+.*)\s*$/) {
                $skilldescs{$cat}->{$skill} .= " $1";
            }
            elsif ($cat && $line =~ /^\s*(\S+.*)$/) {
                $catdescs{$cat} .= " $1";
            }
        }

        foreach $cat (@cats) {
            my $obj_cat =
              Foswiki::Plugins::SkillsPlugin::Category->new(
                  $cat, $skills{$cat}, $catdescs{$cat}, $skilldescs{$cat});
            push @_categories, $obj_cat;
        }
    }

    $_loaded = 1;

    return 1;
}

# returns an array of all category names
sub getCategoryNames {
    my $self = shift;

    $self->_load unless $_loaded;

    my @catNames;

    my $it = $self->eachCat;
    while ( $it->hasNext() ) {
        my $obj_cat = $it->next();
        push @catNames, $obj_cat->name;
    }
    return \@catNames;
}

# sorted iterator of category objects
sub eachCat {
    my $self = shift;

    $self->_load unless $_loaded;

    my @sorted = sort { $a->name cmp $b->name } @_categories;

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@sorted );
}

# saves the skills to file
sub _saveSkillsToWorking {
    my $self = shift;

    _Debug('Saving skills.txt');

    my $out =
"# This file is generated. Do NOT edit unless you are sure what you're doing!\n";

    my $it = $self->eachCat;
    while ( $it->hasNext() ) {
        my $obj_cat = $it->next();
        $out .= $obj_cat->name . ':'
          . join( ',', @{ $obj_cat->getSkillNames } ) . "\n";
    }

    my $workArea = Foswiki::Func::getWorkArea('SkillsPlugin');

    Foswiki::Func::saveFile( $workArea . '/skills.txt', $out );
}

sub save {
    my $self = shift;

    my $topic = Foswiki::Func::getPreferencesValue('SKILLSPLUGIN_SKILLSTOPIC');

    if (!$topic) {
        _saveSkillsToWorking();
    } else {
        (my $web, $topic) = Foswiki::Func::normalizeWebTopicName(
            undef, $topic);

        unless (Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef, $topic, $web )) {
            die "Cannot change SKILLSPLUGIN_SKILLSTOPIC $web.$topic";
        }

        my ($meta, $text);
        if (Foswiki::Func::topicExists($web, $topic)) {
            ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
            # Hack off the old categories
            $text =~ s/(\n|^)---\+.*$//s;
        } else {
            $text = <<HERE;
This topic is maintained by the %SYSTEMWEB%.SkillsPlugin, and will be
rewritten by the plugin if the set of skills changes.

Each category is defined by a top-level heading, followed by any number of
skills in second-level headings. Both categories and skills can be followed
by a block of text that describes the category/skill.

HERE
        }

        my $it = $self->eachCat;
        while ( $it->hasNext() ) {
            my $obj_cat = $it->next();
            $text .= "---+ ".$obj_cat->name()."\n";
            $text .= $obj_cat->description()."\n";
            foreach my $skill (@{ $obj_cat->getSkillNames() } ) {
                $text .= "---++ $skill\n";
                $text .= $obj_cat->description($skill)."\n";
            }
        }

        Foswiki::Func::saveTopic( $web, $topic, $meta, $text);
    }
    return 1;
}

# adds new skill to category
sub addNewSkill {
    my $self = shift;

    my ( $pSkill, $pCat ) = @_;

    my $obj_cat = $self->getCategoryByName($pCat);

    # check category exists and skill does not already exist
    return 'Could not find category/category does not exist.' unless $obj_cat;
    return 'Skill already exists.' if ( $obj_cat->skillExists($pSkill) );

    # add skill to category
    $obj_cat->addSkill($pSkill);

    # save
    $self->save() || return 'Error saving';

    return undef;    # no error
}

sub renameSkill {
    my $self = shift;

    my ( $cat, $oldSkill, $newSkill ) = @_;

    my $obj_cat = $self->getCategoryByName($cat);
    return "Could not find category/category does not exist - '$cat'."
      unless $obj_cat;

    my $er = $obj_cat->renameSkill( $oldSkill, $newSkill );
    return $er if $er;

    $self->save() || return 'Error saving';

    return undef;
}

sub moveSkill {
    my $self = shift;

    my ( $skill, $oldCat, $newCat ) = @_;

    my $obj_oldCat = $self->getCategoryByName($oldCat);
    return "Could not find category/category does not exist - '$oldCat'."
      unless $obj_oldCat;
    my $obj_newCat = $self->getCategoryByName($newCat);
    return "Could not find category/category does not exist - '$newCat'."
      unless $obj_newCat;

    return "Skill '$skill' already exists in category '$newCat'"
      if $obj_newCat->skillExists($skill);

    my $err;

    # add skill to new category
    $obj_newCat->addSkill($skill);

    # delete skill from old category
    $obj_oldCat->deleteSkill($skill);

    $self->save() || return 'Error saving';

    return undef;
}

sub deleteSkill {
    my $self = shift;

    my ( $cat, $skill ) = @_;

    my $obj_cat = $self->getCategoryByName($cat);
    return "Could not find category/category does not exist - '$cat'."
      unless $obj_cat;

    my $er = $obj_cat->deleteSkill($skill);
    return $er if $er;

    $self->save() || return 'Error saving';

    return undef;
}

sub addNewCategory {
    my $self = shift;

    my ($newCat) = @_;

    # check category does not already exist
    return "Category '$newCat' already exists."
      if ( $self->categoryExists($newCat) );

    # create new object and add to array
    my $new_obj_cat = Foswiki::Plugins::SkillsPlugin::Category->new($newCat);
    push @_categories, $new_obj_cat;

    # save
    $self->save() || return 'Error saving';

    return undef;    # no error
}

sub renameCategory {
    my $self = shift;

    my ( $oldCat, $newCat ) = @_;

    # check category does not already exist
    return "Category '$newCat' already exists"
      if ( $self->categoryExists($newCat) );

    my $obj_cat = $self->getCategoryByName($oldCat);
    return "Could not find category/category does not exist - '$oldCat'."
      unless $obj_cat;

    # change the name
    $obj_cat->name($newCat);

    # save
    $self->save() || return 'Error saving';

    return undef;
}

sub deleteCategory {
    my $self = shift;

    my ($cat) = @_;

    return "$cat does not exist" unless $self->categoryExists($cat);

    my @newCategories;

    my $it = $self->eachCat;
    while ( $it->hasNext() ) {
        my $obj_cat = $it->next();
        next if $obj_cat->name eq $cat;    # skip if it is cat to delete
        push( @newCategories, $obj_cat );
    }

    # replace the categories with the ones we want to keep
    @_categories = @newCategories;

    $self->save() || return 'Error saving';

    return undef;
}

sub categoryExists {
    my $self = shift;

    if ( $self->getCategoryByName(shift) ) {
        return 1;
    }
    else {
        return undef;
    }
}

# returns the category obj for the particular category
sub getCategoryByName {
    my $self = shift;

    my $cat = shift || return undef;

    # ensure loaded
    $self->_load unless $_loaded;

    my $it = $self->eachCat;
    while ( $it->hasNext() ) {
        my $obj_cat = $it->next();
        if ( $obj_cat->name eq $cat ) {
            return $obj_cat;
        }
    }
    return undef;
}

sub _Debug {
    my $text = shift;
    my $debug = $Foswiki::cfg{Plugins}{SkillsPlugin}{Debug} || 0;
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::SkillsPlugin::SkillsStore: $text")
      if $debug;
}

sub _Warn {
    my $text = shift;
    Foswiki::Func::writeWarning(
        "- Foswiki::Plugins::SkillsPlugin::SkillsStore: $text");
}

1;
