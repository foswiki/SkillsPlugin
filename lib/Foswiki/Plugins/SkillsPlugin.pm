# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 - 2009 Andrew Jones, andrewjones86@googlemail.com
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

package Foswiki::Plugins::SkillsPlugin;

# Conditionally required in this module
#require Foswiki::Plugins::SkillsPlugin::Category;
#require Foswiki::Plugins::SkillsPlugin::UserSkill;
#require Foswiki::Plugins::SkillsPlugin::UserSkills;
#require Foswiki::Plugins::SkillsPlugin::SkillsStore;

use strict;

use JSON ();

# Plugin Variables
our $VERSION           = '$Rev$';
our $RELEASE           = '16 Jul 2009';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
  'Allows users to list their skills, which can then be searched';

our $doneHeads = 0;

# ========================= INIT
sub initPlugin {

    # Register tag %SKILLS%
    Foswiki::Func::registerTagHandler( 'SKILLS', \&_handleTag );
    # Register tag %SKILLRATINGS%
    Foswiki::Func::registerTagHandler( 'SKILLRATINGS', \&_SKILLRATINGS );

    # Register REST handlers
    Foswiki::Func::registerRESTHandler(
        'addNewCategory', \&_restAddNewCategory );
    Foswiki::Func::registerRESTHandler(
        'renameCategory', \&_restRenameCategory );
    Foswiki::Func::registerRESTHandler(
        'deleteCategory', \&_restDeleteCategory );
    Foswiki::Func::registerRESTHandler(
        'addNewSkill',    \&_restAddNewSkill );
    Foswiki::Func::registerRESTHandler(
        'renameSkill',    \&_restRenameSkill );
    Foswiki::Func::registerRESTHandler(
        'moveSkill',      \&_restMoveSkill );
    Foswiki::Func::registerRESTHandler(
        'deleteSkill',    \&_restDeleteSkill );
    Foswiki::Func::registerRESTHandler(
        'search', \&_restSearch );
    Foswiki::Func::registerRESTHandler(
        'getCategories', \&_restGetCategories );
    Foswiki::Func::registerRESTHandler(
        'getSkills',     \&_restGetSkills );
    Foswiki::Func::registerRESTHandler(
        'getSkillDetails', \&_restGetSkillDetails );
    Foswiki::Func::registerRESTHandler(
        'addEditSkill', \&_restAddEditSkill );

    Foswiki::Func::registerRESTHandler(
        'getSkillsAndDetails', \&_restGetSkillsAndDetails );
    Foswiki::Func::registerRESTHandler(
        'saveUserChanges', \&_restSaveUserChanges );

    _Debug("initPlugin is OK");

    return 1;
}

sub _getLevels {
    my $names = $Foswiki::cfg{SkillsPlugin}{Levels}
      || "None,Ancient Knowledge,Working Knowledge,Expert,Guru";
    my @levels = split(/,\s*/, $names);
    return \@levels;
}

# Generate the divs that contain the tooltips
sub _genTooltips {
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $categories =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;
    my $out = '';
    while ( $categories->hasNext() ) {
        my $obj_cat = $categories->next();
        my $catid = _urlEncode($obj_cat->name());
        my $desc = Foswiki::Func::renderText($obj_cat->description());
        $out .= "<div class='skillsTooltip' id='$catid'>$desc</div>";
        foreach my $skill (@{$obj_cat->{SKILLS}}) {
            $desc = Foswiki::Func::renderText($skill->description($skill));
            my $skid = _urlEncode($skill->name());
            $out .= "<div class='skillsTooltip' id='$catid.$skid'>$desc</div>";
        }
    }
    return $out;
}

# ========================= TAGS
sub _handleTag {

    my $out = '';

    my $action =
         $_[1]->{action}
      || $_[1]->{_DEFAULT}
      || return 'No action specified';

    my $start = "<noautolink>\n";
    my $end   = "\n</noautolink>";

    $doneHeads = 0;

    for ($action) {
        /user/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagUserSkills( $_[1] ) . $end,
          last;

        #    /group/ and $out = $start . Foswiki::Plugins::SkillsPlugin::Tag::_tagGroupSkills($_[1]) . $end, last; # shows skills for a particular group
        /browse/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagBrowseSkills( $_[1] )
          . $end, last;
        /editall/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagEditAllSkills( $_[1] ) . $end,
          last;
        /edit/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagEditSkills( $_[1] ) . $end,
          last;
        /showskill/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagShowSkills( $_[1] ) . $end,
          last;
        /showcat/
          and $out =
            $start
          . Foswiki::Plugins::SkillsPlugin::_tagShowCategories( $_[1] )
          . $end, last;    # show all categories in a format
        /^search$/
          and $out =
          $start . Foswiki::Plugins::SkillsPlugin::_tagSearchForm( $_[1] ) . $end,
          last;            # creates a search form
        /searchresults/
          and $out = $start . '<div id="search-skill-results"></div>' . $end,
          last;            # container for the results

        # action not valid
        $out =
          "<span class='foswikiAlert'>Error: Unknown action ('$action')</span>",
          last;
    }

    #$allowedit = 0;

    return $out;
}

sub _SKILLRATINGS {
    my ($session, $params) = @_;

    my $format =
      defined $params->{_DEFAULT} ? $params->{_DEFAULT}
          : defined $params->{format} ? $params->{format}
              : '$name: $value';
    my $marker =
      defined $params->{marker} ? $params->{marker} : 'selected';
    my $separator =
      defined $params->{separator} ? $params->{separator} : '$n()';
    my $selection =
      defined $params->{selection} ? $params->{selection} : -1;
    my $levels = _getLevels();
    $selection = $#$levels if $selection eq '$';
    my $from =
      defined $params->{from} ? ($params->{from} || 0) : 0;
    my $to =
      defined $params->{to} ? ($params->{to} || $#$levels) : $#$levels;

    my @values = ();
    foreach my $value ($from..$#$levels) {
        my $name = $levels->[$value];
        my $mark = ($value == $selection) ? $marker : '';
        my $item = $format;
        $item =~ s/\$name/$name/g;
        $item =~ s/\$value/$value/g;
        $item =~ s/\$marker/$mark/g;
        push(@values, $item);
    }
    my $out = join($separator, @values);
    return Foswiki::Func::decodeFormatTokens($out);
}

# allows the user to print all categories in format of their choice
sub _tagShowCategories {
    my $params = shift;

    return _showCategories( $params->{format}, $params->{separator} );
}

sub _tagShowSkills {
    my $params = shift;

    return _showSkills(
        $params->{category}, $params->{format}, $params->{separator},
        $params->{prefix},   $params->{suffix}
    );
}

# creates a form allowing users to edit their skills
sub _tagEditSkills {
    my $params = shift;
    my $user = Foswiki::Func::getWikiName();
    my $style = $params->{style} || '';

    my $out = Foswiki::Func::readTemplate('skillsedit'.$style);

    my $jsVars = <<JS;
SkillsPlugin.vars.addEditSkills = 1;
SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";
JS
    _addHeads($jsVars);

    return $out._genTooltips();
}

# creates a form allowing users to edit their skills
sub _tagEditAllSkills {
    my $params = shift;
    my $user = Foswiki::Func::getWikiName();

    my $out = Foswiki::Func::readTemplate('skillseditall');

    my $jsVars = <<JS;
SkillsPlugin.vars.editAllSkills = 1;
SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";
JS
    _addHeads($jsVars);

    return $out._genTooltips();
}

sub _tagUserSkills {

    my $params = shift;

    my $user   = $params->{user}   || Foswiki::Func::getWikiName();
    my $twisty = $params->{twisty} || 'closed';

    my $out = Foswiki::Func::readTemplate('skillsuserview');

    my $tmplCat = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:category");
    my $tmplCatContStart = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:categorycontainerstart");
    my $tmplSkillStart = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:skillstart");
    my $tmplSkill = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:skill");
    my $tmplPreRating = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:prerating");
    my $tmplRating = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:rating");
    my $tmplPostRating = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:postrating");
    my $tmplComment = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:comment");
    my $tmplSkillEnd = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:skillend");
    my $tmplCatContEnd = Foswiki::Func::expandTemplate(
        "skills:userview:repeated:categorycontainerend");

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $skills = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ;    # FIXME: dont need to go here!
    my $userSkills = Foswiki::Plugins::SkillsPlugin::UserSkills->new();

    my $jsVars =
      "if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; "
      ;    # create namespace in JS

    my $levels = _getLevels();

    my $body = '';

    my $itCategories = $skills->eachCat;
    while ( $itCategories->hasNext() ) {
        my $cat = $itCategories->next();

        my $catDone  = 0;
        my $categoryOut = '';
        my $skillDone = 0;

        # iterator over skills
        my $itSkills = $cat->eachSkill;
        while ( $itSkills->hasNext() ) {
            my $skill = $itSkills->next();

            # does user have this skill?
            if ( my $obj_userSkill =
                $userSkills->getSkillForUser( $user, $skill->name, $cat->name )
              )
            {

                $skillDone = 1;

                # category
                unless ( $catDone == 1 ) {
                    $categoryOut .= $tmplCat;
                    $categoryOut .= $tmplCatContStart;
                    $catDone = 1;
                }

                my $skillOut .= $tmplSkillStart . $tmplSkill;

                # rating
                my $i = 1;
                while ( $i < $obj_userSkill->rating ) {
                    $skillOut .= $tmplPreRating;
                    $i++;
                }
                $skillOut .= $tmplRating;
                $i++;
                while ( $i <= $#$levels ) {
                    $skillOut .= $tmplPostRating;
                    $i++;
                }

                # comment
                $skillOut .= $tmplComment;

                $skillOut .= $tmplSkillEnd;

                my $url = Foswiki::Func::getScriptUrl(
                    'Main', 'WebHome', 'oops',
                    template => 'oopsgeneric',
                    param1   => 'Skills Plugin Comment',
                    param2   => "Comment for skill '"
                      . $skill->name
                        . "' by $user",
                    param3 =>
                      "$user has logged the following comment next to skill '"
                        . $skill->name . "'.",
                    param4 => $obj_userSkill->comment
                   );
                $url .= ';cover=skills';
                $skillOut =~ s/%COMMENTLINKURL%/$url/g;

                if ( $obj_userSkill->comment ) {
                    $skillOut =~ s/%COMMENTLINKCLASS%/SkillsPluginComments/g;
                } else {
                    $skillOut =~ s/%COMMENTLINKCLASS%/foswikiHidden/g;
                }

                $skillOut =~ s/%SKILLID%/_urlEncode($skill->name())/ge;
                $skillOut =~ s/%SKILLNAME%/$skill->name()/ge;

                $categoryOut .= $skillOut;
            }
        }

        # subsitutions
        $categoryOut =~ s/%CATEGORYID%/_urlEncode( $cat->name() )/ge;
        $categoryOut =~ s/%CATEGORYNAME%/$cat->name()/ge;

        $categoryOut .= $tmplCatContEnd if ( $skillDone );

        $body .= $categoryOut;
    }

    $out =~ s/%REPEAT%/$body/g;
    $out =~ s/%SKILLUSER%/$user/g;

    $jsVars .= <<JS;
SkillsPlugin.vars.twistyState = '$twisty';
SkillsPlugin.vars.twistyOpenImgSrc = '%ICONURL{toggleopen}%';
SkillsPlugin.vars.twistyCloseImgSrc = '%ICONURL{toggleclose}%';
SkillsPlugin.vars.viewUserSkills = 1;
JS
    _addHeads($jsVars);

    return $out._genTooltips();
}

sub _tagSearchForm {
    my $out = Foswiki::Func::readTemplate('skillssearchform');

    _addHeads(<<JS);
SkillsPlugin.vars.searchSkills = 1;
SkillsPlugin.vars.restUrl = "%SCRIPTURL{"rest"}%";
JS

    return $out._genTooltips();
}

sub _tagBrowseSkills {

    my $params = shift;

    my $twisty = $params->{twisty} || 'closed';

    my $out    = Foswiki::Func::readTemplate('skillsbrowseview');

    my $tmplCat = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:category");
    my $tmplCatContStart = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:categorycontainerstart");
    my $tmplSkillStart = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:skillstart");
    my $tmplSkill = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:skill");
    my $tmplUserStart = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:userstart");
    my $tmplUser = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:user");
    my $tmplUserEnd = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:userend");
    my $tmplPreRating = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:prerating");
    my $tmplRating = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:rating");
    my $tmplPostRating = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:postrating");
    my $tmplComment = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:comment");
    my $tmplSkillEnd = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:skillend");
    my $tmplCatContEnd = Foswiki::Func::expandTemplate(
        "skills:browseview:repeated:categorycontainerend");

    # loop over all skills from skills.txt
    # if a user has this skill, output them

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $skills = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ;    # FIXME: dont need to go here!
    my $userSkills = Foswiki::Plugins::SkillsPlugin::UserSkills->new();

    my $body = '';

    # loop over all users that have skills
    # if they do, store in hash/array ## CANT cos C++, etc
    # loop over array and do the output

    # my $allUserSkills = $userSkills->allUsers();
    #
    # my $outSkills;
    #
    # # each user with skills
    # for my $user( sort keys %{ $allUserSkills } ){
    #
    # # loop over all this users skills
    # for my $user_obj( @{ $allUserSkills->{ $user } } ){
    #
    # next unless( $skills->categoryExists( $user_obj->category ) );
    # next unless( $skills->getCategoryByName( $user_obj->category )->skillExists( $user_obj->name ) );
    #
    # # category
    # $outSkills->{ $user_obj->category } = {} unless $outSkills->{ $user_obj->category };
    # # skill
    # $outSkills->{ $user_obj->category }->{ $user_obj->name } unless $outSkills->{ $user_obj->category }->{ $user_obj->name };
    #
    # #%outSkills->{ $user_obj->category }->{ $user_obj->name }->{ $user } = $user_obj;
    #
    # # check the category and skill is defined
    # # add to hash
    # }
    #
    # return $user;
    # }
    #
    # return "hi" . $allUserSkills->{'AndrewJones'}[0]->name;
    #return "hi";

    my $allUsers = $userSkills->allUsers();
    my $levels = _getLevels();

    my $itCategories = $skills->eachCat;
    while ( $itCategories->hasNext() ) {
        my $cat = $itCategories->next();

        my $catName = $cat->name;

        my $categoryOut = $tmplCat . $tmplCatContStart;

        # iterator over skills
        my $itSkills = $cat->eachSkill;
        while ( $itSkills->hasNext() ) {
            my $skill = $itSkills->next();

            my $skillName = $skill->name;

            my $skillOut = $tmplSkillStart . $tmplSkill . $tmplSkillEnd;

            # now need to iterate over users and find out if they have
            # this skill.
            # users should only be loaded the first time, the rest is in
            # memory if this was an iterator of each user with skills
            # my $users = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
            #  ->getUsersForSkill( $skillName, $catName );
            #for my $user ( sort keys %{ $users } ) {
            #my $obj_userSkill = $allUsers->{ $user };

            for my $user ( sort keys %{$allUsers} ) {
                for my $obj_userSkill ( @{ $allUsers->{$user} } ) {

                    next
                      unless ( $obj_userSkill->category eq $catName
                        and $obj_userSkill->name eq $skillName );

                    $skillOut .= $tmplUserStart;
                    $skillOut .= $tmplUser;

                    # rating
                    my $i = 1;
                    while ( $i < $obj_userSkill->rating ) {
                        $skillOut .= $tmplPreRating;
                        $i++;
                    }
                    $skillOut .= $tmplRating;
                    $i++;
                    while ( $i <= $#$levels ) {
                        $skillOut .= $tmplPostRating;
                        $i++;
                    }

                    # comment
                    $skillOut .= $tmplComment;

                    # comment link
                    # SMELL: do this using a tooltip
                    my $url = Foswiki::Func::getScriptUrl(
                        'Main', 'WebHome', 'oops',
                        template => 'oopsgeneric',
                        param1   => 'Skills Plugin Comment',
                        param2   => "Comment for skill '"
                          . $obj_userSkill->name
                            . "' by $user",
                        param3 =>
                          "$user has logged the following comment next to skill '"
                            . $obj_userSkill->name . "'.",
                        param4 => $obj_userSkill->comment
                       );
                    $url .= ';cover=skills';
                    if ( $obj_userSkill->comment() ) {
                        $skillOut =~ s/%COMMENTLINKCLASS%/foswikiHidden/g;
                    } else {
                        $skillOut =~ s/%COMMENTLINKCLASS%/SkillsPluginComments/g;
                    }
                    $skillOut =~ s/%COMMENTLINKURL%/$url/g;
                    $skillOut =~ s/%SKILLUSER%/$user/g;
                    $skillOut .= $tmplUserEnd;
                }
            }

            $skillOut =~ s/%SKILLID%/_urlEncode($skillName)/ge;
            $skillOut =~ s/%SKILLNAME%/$skillName/ge;

            $categoryOut .= $skillOut;
        }

        # subsitutions
        $categoryOut =~ s/%CATEGORYID%/_urlEncode( $cat->name() )/ge;
        $categoryOut =~ s/%CATEGORYNAME%/$cat->name()/ge;

        $categoryOut .= $tmplCatContEnd;

        $body .= $categoryOut;
    }

    $out =~ s/%REPEAT%/$body/g;

    my $jsVars = <<JS;
SkillsPlugin.vars.twistyState = '$twisty';
SkillsPlugin.vars.twistyOpenImgSrc = '%ICONURL{toggleopen}%';
SkillsPlugin.vars.twistyCloseImgSrc = '%ICONURL{toggleclose}%';
SkillsPlugin.vars.browseSkills = 1;
JS
    _addHeads($jsVars);

    return $out._genTooltips();
}

# ========================= REST
sub _restAddNewCategory {

    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: addNewCategory');

    my $request = Foswiki::Func::getCgiQuery();
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        $request->param('topic') );

    my $newCat = $request->param('newcategory');

    unless ( Foswiki::Func::isAnAdmin() ) {
        if ( my $pref = Foswiki::Func::getPreferencesValue('SKILLSPLUGIN_ALLOWADDSKILLS') ) {
            my @allowedUsers = split( /,/, $pref );
            my $user = Foswiki::Func::getWikiName();
            return _returnFromRest( $web, $topic,
"Error adding category '$newCat' - You are not permitted to add categories or skills ($user)."
            ) unless grep( /$user/, @allowedUsers );
        }
    }

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $error =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->addNewCategory($newCat);
    return _returnFromRest( $web, $topic,
        "Error adding category '$newCat' - $error" )
      if $error;

    _Log("Category $newCat added");

    # success
    return _returnFromRest( $web, $topic, "New category '$newCat' added." );
}

sub _restRenameCategory {

    _Debug('REST handler: renameCategory');

    my $request = Foswiki::Func::getCgiQuery();
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        $request->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    my $oldCat = $request->param('oldcategory')
      || return _returnFromRest( $web, $topic,
        "'oldcategory' parameter is required'" );
    my $newCat = $request->param('newcategory')
      || return _returnFromRest( $web, $topic,
        "'newcategory' parameter is required'" );

    # rename in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $renameSkillsError = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->renameCategory( $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
        "Error renaming category '$oldCat' to '$newCat' - $renameSkillsError" )
      if $renameSkillsError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $renameUserError = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->renameCategory( $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
        "Error renaming category '$oldCat' to '$newCat' - $renameUserError" )
      if $renameUserError;

    _Log("Category $oldCat renamed to $newCat");

    # success
    return _returnFromRest( $web, $topic,
        "Category '$oldCat' has been renamed to '$newCat'." );
}

sub _restDeleteCategory {
    _Debug('REST handler: deleteCategory');

    my $request = Foswiki::Func::getCgiQuery();
    my $cat = $request->param('oldcategory');

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        $request->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    # delete in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $deleteStoreError =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->deleteCategory($cat);
    return _returnFromRest( $web, $topic,
        "Error deleting category '$cat' - $deleteStoreError" )
      if $deleteStoreError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $deleteUserError =
      Foswiki::Plugins::SkillsPlugin::UserSkills->new()->deleteCategory($cat);
    return _returnFromRest( $web, $topic,
        "Error deleting category '$cat' - $deleteUserError" )
      if $deleteUserError;

    _Log("Category $cat deleted");

    # success
    return _returnFromRest( $web, $topic,
        "Category '$cat' has been deleted, along with its skills." );
}

# adds a new skill
# if the ALLOWADDSKILLS preference is set, only the listed people and admins can add skills
# otherwise everyone can
sub _restAddNewSkill {

    _Debug('REST handler: addNewCategory');

    my $request = Foswiki::Func::getCgiQuery();
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        $request->param('topic') );

    my $newSkill = $request->param('newskill');
    my $cat      = $request->param('incategory');

    unless ( Foswiki::Func::isAnAdmin() ) {
        if ( my $pref = Foswiki::Func::getPreferencesValue('SKILLSPLUGIN_ALLOWADDSKILLS') ) {
            my @allowedUsers = split( /,/, $pref );
            my $user = Foswiki::Func::getWikiName();
            return _returnFromRest( $web, $topic,
"Error adding skill '$newSkill' to category '$cat' - You are not permitted to add skills ($user)."
            ) unless grep( /$user/, @allowedUsers );
        }
    }

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $error = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->addNewSkill( $newSkill, $cat );
    return _returnFromRest( $web, $topic,
        "Error adding skill '$newSkill' to category '$cat' - $error" )
      if $error;

    _Log("Skill $newSkill added");

    # success
    return _returnFromRest( $web, $topic, "New skill '$newSkill' added." );
}

# renames a skill
# only admins can do this
sub _restRenameSkill {
    _Debug('REST handler: renameSkill');

    my $request = Foswiki::Func::getCgiQuery();
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        $request->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    my ( $category, $oldSkill ) =
      split( /\|/, $request->param('oldskill') )
      ;                                   # oldskill looks like Category|Skill
    my $newSkill = $request->param('newskill');

    # rename in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $renameStoreError = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->renameSkill( $category, $oldSkill, $newSkill );
    return _returnFromRest( $web, $topic,
"Error renaming skill '$oldSkill' to '$newSkill' in category '$category' - $renameStoreError"
    ) if $renameStoreError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $renameUserError = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->renameSkill( $category, $oldSkill, $newSkill );
    return _returnFromRest( $web, $topic,
"Error renaming skill '$oldSkill' to '$newSkill' in category '$category' - $renameUserError"
    ) if $renameUserError;

    _Log("Skill $oldSkill renamed to $newSkill in category $category");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$oldSkill' has been renamed to '$newSkill'." );
}

# moves a skill from one category to another
# only admins can do this
sub _restMoveSkill {
    _Debug('REST handler: moveSkill');

    my $request = Foswiki::Func::getCgiQuery();
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        $request->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    my ( $oldCat, $skill ) =
      split( /\|/, $request->param('movefrom') )
      ;                                   # movefrom looks like Category|Skill
    my $newCat = $request->param('moveto');

    _Debug("$skill, $oldCat, $newCat");

    # rename in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $moveStoreError = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->moveSkill( $skill, $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
"Error moving skill '$skill' from '$oldCat' to '$newCat' - $moveStoreError"
    ) if $moveStoreError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $moveUserError = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->moveSkill( $skill, $oldCat, $newCat );
    return _returnFromRest( $web, $topic,
"Error moving skill '$skill' from '$oldCat' to '$newCat' - $moveUserError"
    ) if $moveUserError;

    _Log("Skill $skill moved from $oldCat to $newCat");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$skill' has been moved from '$oldCat' to '$newCat'." );
}

# deletes a skill from the skill database
# only admins can do this
sub _restDeleteSkill {
    _Debug('REST handler: deleteSkill');

    my $request = Foswiki::Func::getCgiQuery();
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( undef,
        $request->param('topic') );

    return _returnFromRest('Error - user is not an admin')
      unless Foswiki::Func::isAnAdmin();    # check admin

    my ( $cat, $oldSkill ) =
      split( /\|/, $request->param('oldskill') )
      ;                                   # oldskill looks like Category|Skill

    # delete in skills.txt
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $deleteStoreError = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->deleteSkill( $cat, $oldSkill );
    return _returnFromRest( $web, $topic,
        "Error deleting skill '$oldSkill' - $deleteStoreError" )
      if $deleteStoreError;

    # rename in users
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $deleteUserError = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->deleteSkill( $cat, $oldSkill );
    return _returnFromRest( $web, $topic,
        "Error deleting skill '$oldSkill' - $deleteUserError" )
      if $deleteUserError;

    _Log("Skill $oldSkill deleted");

    # success
    return _returnFromRest( $web, $topic,
        "Skill '$oldSkill' has been deleted from category '$cat'." );
}

# returns all categories in a comma seperated list
sub _restGetCategories {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request = Foswiki::Func::getCgiQuery();
    _Debug('REST handler: getCategories');

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $cats =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->getCategoryNames();

    return JSON::to_json($cats);
}

# returns all skills for a particular category in a comma seperated list
sub _restGetSkills {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkills');

    my $request = Foswiki::Func::getCgiQuery();
    my $cat = $request->param('category');
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $categories = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
      ->eachCat();

    my $skills;
    while ( $categories->hasNext() ) {
        my $obj_cat = $categories->next();
        if ( $cat eq $obj_cat->name ) {
            $skills = $obj_cat->getSkillNames();
            return JSON::to_json($skills);
        }
    }
    return '[]';
}

# gets all the details for skills in a particular category for the
# current user. If 'cat' isn't given, get details for all categories.
# results is returned as a JSON hash indexed by category name, where
# each value is a hash indexed by skill name mapping to priority and
# comment.
sub _restGetSkillsAndDetails {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request = Foswiki::Func::getCgiQuery();
    my $cat   = $request->param('category');

    my $user = Foswiki::Func::getWikiName();

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    require Foswiki::Plugins::SkillsPlugin::UserSkills;

    if (!$cat) {
        my $cats =
          Foswiki::Plugins::SkillsPlugin::SkillsStore->new()
              ->getCategoryNames();
        $cat = join('|', @$cats);
    }

    my $categories =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;
    my %data = ();
    my $us = Foswiki::Plugins::SkillsPlugin::UserSkills->new();
    while ( $categories->hasNext() ) {
        my $obj_cat = $categories->next();
        if ( $obj_cat->name() =~ /^($cat)$/ ) {
            my %cat_data;
            my $skills = $obj_cat->getSkillNames();
            foreach my $skill (@$skills) {
                my %user_data = ();
                my $obj_userSkill =
                  $us->getSkillForUser( $user, $skill, $cat );
                if ($obj_userSkill) {
                    # The user has the skill
                    $user_data{rating}   = $obj_userSkill->rating;
                    $user_data{comment}  = $obj_userSkill->comment;
                } # otherwise they don't have it
                $cat_data{$skill} = \%user_data;
            }
            $data{$obj_cat->name()} = \%cat_data;
        }
    }
    return JSON::to_json(\%data);
}

# Save changes made in the flat category form
sub _restSaveUserChanges {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $request = Foswiki::Func::getCgiQuery();
    my $user = Foswiki::Func::getWikiName();

    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $us = Foswiki::Plugins::SkillsPlugin::UserSkills->new();

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $categories =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;

    my $error;
    while ( !$error && $categories->hasNext() ) {
        my $obj_cat = $categories->next();
        my $cat = $obj_cat->name();
        my $skills = $obj_cat->getSkillNames();
        foreach my $skill (@$skills) {
            my $rating = $request->param(
                "editall.$cat.$skill-rating");
            my $comment = $request->param(
                "editall.$cat.$skill-comment");
            if (defined $rating || defined $comment) {
                $error = $us->addEditUserSkill(
                    $user, $cat, $skill, $rating, $comment );
                last if $error;
            }
        }
    }

    my $message;
    if ($error) {
        $message = "Error updating skills - $error";
    }
    else {
        $message = "Skills updated.";
    }
    return $message;
}

# gets all the details for a particular skill for the user logged in
# i.e. rating and comments
sub _restGetSkillDetails {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkillDetails');

    my $request = Foswiki::Func::getCgiQuery();
    my $cat   = $request->param('category');
    my $skill = $request->param('skill');

    my $user = Foswiki::Func::getWikiName();

    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $obj_userSkill = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->getSkillForUser( $user, $skill, $cat );

    unless ($obj_userSkill) {
        return '{}';
    }

    return JSON::to_json(
        {
            skill    => $obj_userSkill->name,
            category => $obj_userSkill->category,
            rating   => $obj_userSkill->rating,
            comment  => $obj_userSkill->comment,
        });
}

# allows a user to add a new skill or edit an existing one
sub _restAddEditSkill {
    my ( $session, $plugin, $verb, $response ) = @_;

    _Debug('REST handler: getSkillDetails');

    my $request = Foswiki::Func::getCgiQuery();
    my $cat     = $request->param('category');
    my $skill   = $request->param('skill');
    my $rating  = $request->param('addedit-skill-rating');
    my $comment = $request->param('comment');

    die unless defined($cat) && defined($skill);

    my $user = Foswiki::Func::getWikiName();

    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $error = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->addEditUserSkill( $user, $cat, $skill, $rating, $comment );

    my $message;
    if ($error) {
        $message = "Error adding/editing skill '$skill' - $error";
    }
    else {
        $message = "Skill '$skill' added/edited.";
    }

    return $message;
}

sub _restSearch {
    my $request = Foswiki::Func::getCgiQuery();
    my $cat        = $request->param('category');
    my $skill      = $request->param('skill');
    my $ratingFrom = $request->param('ratingFrom');
    my $ratingTo   = $request->param('ratingTo');

    return 'Error: Category and Skill must be defined'
      unless ( $skill and $cat );

    my $out = Foswiki::Func::readTemplate('skillssearchresults');

    my $tmplRepeat =
      Foswiki::Func::readTemplate('skillssearchresultsrepeated');

    my $tmplUserStart = Foswiki::Func::expandTemplate(
        'skills:searchresults:repeated:userstart');
    my $tmplUser = Foswiki::Func::expandTemplate(
        'skills:searchresults:repeated:user');
    my $tmplRating = Foswiki::Func::expandTemplate(
        'skills:searchresults:repeated:rating');
    my $tmplPreRating = Foswiki::Func::expandTemplate(
        'skills:searchresults:repeated:prerating');
    my $tmplPostRating = Foswiki::Func::expandTemplate(
        'skills:searchresults:repeated:postrating');
    my $tmplComment = Foswiki::Func::expandTemplate(
        'skills:searchresults:repeated:comment');
    my $tmplUserEnd = Foswiki::Func::expandTemplate(
        'skills:searchresults:repeated:userend');

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    require Foswiki::Plugins::SkillsPlugin::UserSkills;
    my $skills     = Foswiki::Plugins::SkillsPlugin::SkillsStore->new();
    my $userSkills = Foswiki::Plugins::SkillsPlugin::UserSkills->new();

    my $repeatedLine;

    # hash of UserSkill objects keyed by user name
    my $users = Foswiki::Plugins::SkillsPlugin::UserSkills->new()
      ->getUsersForSkill( $skill, $cat );

    for my $user ( sort keys %{$users} ) {
        my $obj_userSkill = $users->{$user};

        my $lineOut;

        $lineOut .= $tmplUserStart;

        # skill
        $lineOut .= $tmplUser;

        # rating
        my $i = 1;
        while ( $i < $obj_userSkill->rating ) {
            $lineOut .= $tmplPreRating;
            $i++;
        }
        $lineOut .= $tmplRating;
        $i++;
        while ( $i <= 4 ) {
            $lineOut .= $tmplPostRating;
            $i++;
        }

        # comment
        $lineOut .= $tmplComment;

        $lineOut .= $tmplUserEnd;

        # subsitutions
        $lineOut =~ s/%SKILLUSER%/$user/g;

        # comment link
        my $commentLink = '';
        if ( $obj_userSkill->comment ) {
            my $url = Foswiki::Func::getScriptUrl(
                'Main', 'WebHome', 'oops',
                template => 'oopsgeneric',
                param1   => 'Skills Plugin Comment',
                param2   => "Comment for skill '"
                  . $obj_userSkill->name
                  . "' by $user",
                param3 =>
                  "$user has logged the following comment next to skill '"
                  . $obj_userSkill->name . "'.",
                param4 => $obj_userSkill->comment
            );
            $url .= ';cover=skills';
            $commentLink =
                "<a id='comment|"
              . $obj_userSkill->category . "|"
              . $obj_userSkill->name
              . "' class='SkillsPluginComments' href=\"$url\" target='_blank' >%ICON{note}%</a>";
        }
        $lineOut =~ s/%COMMENTLINK%/$commentLink/g;

        $repeatedLine .= $lineOut;
    }

    $out =~ s/%REPEAT%/$repeatedLine/g;

    $out =~ s/%SEARCHCATEGORY%/$cat/g;
    $out =~ s/%SEARCHSKILL%/$skill/g;
    my $matches = keys( %{$users} );
    $out =~ s/%SEARCHMATCHES%/$matches/g;

    $out = Foswiki::Func::expandCommonVariables($out);

    #$out = Foswiki::Func::renderText( $out );

    return $out;
}

# ========================= FUNCTIONS
# returns all the categories in the defined format
sub _showCategories {
    my ( $format, $separator ) = @_;

    my $hasSeparator = $separator ne '' if $separator;
    my $hasFormat    = $format    ne '' if $format;

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator ||= '';
    $separator =~ s/\$n/\n/go;

    $format = '$category' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    my $text = '';
    my $line = '';

    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $cats =
      Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->getCategoryNames();

    $text = join(
        $separator,
        map {
            $line = $format if $format;
            $line =~ s/\$category/$_/go;
            $line;
          } @{$cats}
    );

    return $text;
}

# allows the user to print all skills in format of their choice
# this can be from a specific category, or all categories
sub _showSkills {

    my ( $cat, $format, $separator, $prefix, $suffix, $catSeparator ) = @_;

    my $hasSeparator = $separator ne '' if $separator;
    my $hasFormat    = $format    ne '' if $format;

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator ||= '';
    $separator =~ s/\$n/\n/go;

    $format = '$skill' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    $prefix =~ s/\$n/\n/go if $prefix;
    $suffix =~ s/\$n/\n/go if $suffix;

    my $text = '';
    my $line = '';

    # get all skills
    # if category is specified, only show skills in that category
    # else, show them all

    # iterator of all categories
    require Foswiki::Plugins::SkillsPlugin::SkillsStore;
    my $categories = Foswiki::Plugins::SkillsPlugin::SkillsStore->new()->eachCat;

    if ($cat) {    # category specified

        my $skills;

        while ( $categories->hasNext() ) {
            my $obj_cat = $categories->next();
            if ( $cat eq $obj_cat->name ) {
                $skills = $obj_cat->getSkillNames;
                last;
            }
        }

        $text = join(
            $separator,
            map {
                $line = $format;
                $line =~ s/\$skill/$_/go;
                $line;
              } @$skills
        );

        return $text;

    }

    # all skills and categories
    else {
        $catSeparator = "\n" unless ( defined $catSeparator && $catSeparator ne '' );

        while ( $categories->hasNext() ) {
            my $obj_cat    = $categories->next();
            my $prefixLine = $prefix;
            $prefixLine =~ s/\$category/$obj_cat->name/goe;
            $prefixLine =~ s/\$n/\n/go;
            $text .= $prefixLine;

            $text .= join(
                $separator,
                map {
                    $line = $format;
                    $line =~ s/\$category/$obj_cat->name/goe;
                    $line =~ s/\$skill/$_/go;
                    $line;
                  } @{ $obj_cat->getSkillNames }
            );

            my $suffixLine = $suffix || '';
            $suffixLine =~ s/\$category/$obj_cat->name/goe;
            $suffixLine =~ s/\$n/\n/go;
            $text .= $suffixLine;

            # seperate each category
            $text .= $catSeparator;
        }

        return $text;
    }
}

# ========================= UTILITIES
sub _addHeads {

    return if $doneHeads;
    $doneHeads = 1;

    # js vars
    my $jsVars;
    if ( my $vars = shift ) {
        $jsVars =
          'if( !SkillsPlugin ) var SkillsPlugin = {}; SkillsPlugin.vars = {}; '
          ;    # create namespace in JS
        $jsVars .= $vars;
    }
    if ( Foswiki::Func::isGuest() ) {
        $jsVars .= 'SkillsPlugin.vars.loggedIn = 0;';
    }
    else {
        $jsVars .= 'SkillsPlugin.vars.loggedIn = 1;';
    }

    # yui
    # adds the YUI Javascript files from header
    # these are from the YahooUserInterfaceContrib, if installed
    # or directly from the internet (See http://developer.yahoo.com/yui/articles/hosting/)
    # TODO: Could be configurable?
    my $yui;
    eval 'use Foswiki::Contrib::YahooUserInterfaceContrib';
    if ( !$@ ) {
        _Debug('YahooUserInterfaceContrib is installed, using local files');
        $yui = "%PUBURL%/%SYSTEMWEB%/YahooUserInterfaceContrib";
    } else {
        _Debug(
            'YahooUserInterfaceContrib is not installed, using Yahoo servers');
        $yui = "http://yui.yahooapis.com/2.5.2";
    }

    my $urlPath = '%PUBURLPATH%/%SYSTEMWEB%/SkillsPlugin';
    my $restPath = '%SCRIPTURL{"rest"}%/SkillsPlugin';

    # add to head
    # FIXME: use the 'requires' parameter? for YUI?
    Foswiki::Func::addToHEAD( 'SKILLSPLUGIN_JS', <<THIS);
<style type="text/css" media="all">
 \@import url("$urlPath/style.css");
</style>
<script type="text/javascript" src="$yui/build/yahoo-dom-event/yahoo-dom-event.js"></script>
<script type="text/javascript" src="$yui/build/connection/connection-min.js"></script>
<script type="text/javascript" src="$yui/build/element/element-beta-min.js"></script>
<script type="text/javascript" src="$yui/build/json/json-min.js"></script>
<script type="text/javascript" src="$yui/build/animation/animation-min.js"></script>
<script type="text/javascript" src="$yui/build/container/container-min.js"></script>
<link rel="stylesheet" type="text/css" href="$yui/build/container/assets/skins/sam/container.css" />
<style>
.skillsSpinner {
 width: 16px;
 height: 16px;
 margin: 0px;
 padding: 0px;
 background-image: url("$urlPath/spinner.gif");
}
</style>
<script language='javascript' type='text/javascript'>$jsVars</script>
<script src="$urlPath/main.js" language="javascript" type="text/javascript">
</script>
THIS
}

# Taken from TagMePlugin (http://twiki.org/cgi-bin/view/Plugins/TagMePlugin)
sub _urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    return $text;
}

# formats a suitible return message from rest functions
sub _returnFromRest {
    my ( $web, $topic, $message ) = @_;

    $message = _urlEncode($message);

    my $url =
        Foswiki::Func::getScriptUrl( $web, $topic, 'view' )
      . '?skillsmessage='
      . $message;
    Foswiki::Func::redirectCgiQuery( undef, $url );
}

# =========================
sub _Debug {
    my $text = shift;
    my $debug = $Foswiki::cfg{Plugins}{SkillsPlugin}{Debug} || 0;
    Foswiki::Func::writeDebug("- SkillsPlugin: $text") if $debug;
}

sub _Warn {
    my $text = shift;
    Foswiki::Func::writeWarning("- SkillsPlugin: $text");
}

# logs actions
# FIXME - should write our own log in work area
sub _Log {
    return;
    my ($message) = @_;

    my $logAction = $Foswiki::cfg{Plugins}{SkillsPlugin}{Log} || 1;
    return unless $logAction;

    my $user = Foswiki::Func::getWikiName();

    my $out = "| date,time | $user | $message |";

    _Debug("Logged: $out");
}

1;
