# --
# Kernel/Modules/AgentITSMWorkOrderDelete.pm - the OTRS::ITSM::ChangeManagement workorder delete module
# Copyright (C) 2003-2010 OTRS AG, http://otrs.com/
# --
# $Id: AgentITSMWorkOrderDelete.pm,v 1.10 2010-02-02 14:51:42 bes Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMWorkOrderDelete;

use strict;
use warnings;

use Kernel::System::ITSMChange;
use Kernel::System::ITSMChange::ITSMWorkOrder;
use Kernel::System::ITSMChange::ITSMCondition;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.10 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (
        qw(ParamObject DBObject LayoutObject LogObject ConfigObject)
        )
    {
        if ( !$Self->{$Object} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Object!" );
        }
    }

    # create additional objects
    $Self->{ChangeObject}    = Kernel::System::ITSMChange->new(%Param);
    $Self->{WorkOrderObject} = Kernel::System::ITSMChange::ITSMWorkOrder->new(%Param);
    $Self->{ConditionObject} = Kernel::System::ITSMChange::ITSMCondition->new(%Param);

    # get config of frontend module
    $Self->{Config} = $Self->{ConfigObject}->Get("ITSMWorkOrder::Frontend::$Self->{Action}");

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed WorkOrderID
    my $WorkOrderID = $Self->{ParamObject}->GetParam( Param => 'WorkOrderID' );

    # check needed stuff
    if ( !$WorkOrderID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => 'No WorkOrderID is given!',
            Comment => 'Please contact the admin.',
        );
    }

    # get workorder data
    my $WorkOrder = $Self->{WorkOrderObject}->WorkOrderGet(
        WorkOrderID => $WorkOrderID,
        UserID      => $Self->{UserID},
    );

    # check error
    if ( !$WorkOrder ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "WorkOrder '$WorkOrderID' not found in database!",
            Comment => 'Please contact the admin.',
        );
    }

    # check permissions
    my $Access = $Self->{ChangeObject}->Permission(
        Type     => $Self->{Config}->{Permission},
        ChangeID => $WorkOrder->{ChangeID},
        UserID   => $Self->{UserID},
    );

    # error screen, don't show workorder delete mask
    if ( !$Access ) {
        return $Self->{LayoutObject}->NoPermission(
            Message    => "You need $Self->{Config}->{Permission} permissions on the change!",
            WithHeader => 'yes',
        );
    }

    if ( $Self->{Subaction} eq 'WorkOrderDelete' ) {

        # delete the workorder
        my $CouldDeleteWorkOrder = $Self->{WorkOrderObject}->WorkOrderDelete(
            WorkOrderID => $WorkOrder->{WorkOrderID},
            UserID      => $Self->{UserID},
        );

        if ($CouldDeleteWorkOrder) {

            # redirect to change, when the deletion was successful
            return $Self->{LayoutObject}->Redirect(
                OP => "Action=AgentITSMChangeZoom&ChangeID=$WorkOrder->{ChangeID}",
            );
        }
        else {

            # show error message, when delete failed
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Was not able to delete the workorder $WorkOrder->{WorkOrderID}!",
                Comment => 'Please contact the admin.',
            );
        }
    }

    # get change that workorder belongs to
    my $Change = $Self->{ChangeObject}->ChangeGet(
        ChangeID => $WorkOrder->{ChangeID},
        UserID   => $Self->{UserID},
    );

    # check if change is found
    if ( !$Change ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not find Change for WorkOrder $WorkOrderID!",
            Comment => 'Please contact the admin.',
        );
    }

    # output header
    my $Output = $Self->{LayoutObject}->Header(
        Title => 'Delete',
    );
    $Output .= $Self->{LayoutObject}->NavigationBar();

    # get affected condition ids
    my $AffectedConditionIDs = $Self->{ConditionObject}->ConditionListByObjectType(
        ObjectType => 'ITSMWorkOrder',
        Selector   => $WorkOrder->{WorkOrderID},
        ChangeID   => $WorkOrder->{ChangeID},
        UserID     => $Self->{UserID},
    ) || [];

    # display list of affected conditions
    if ( @{$AffectedConditionIDs} ) {
        $Self->{LayoutObject}->Block(
            Name => 'WorkOrderInCondition',
            Data => {},
        );

        CONDITIONID:
        for my $ConditionID ( @{$AffectedConditionIDs} ) {

            # get condition
            my $Condition = $Self->{ConditionObject}->ConditionGet(
                ConditionID => $ConditionID,
                UserID      => $Self->{UserID},
            );

            # check condition
            next CONDITIONID if !$Condition;

            $Self->{LayoutObject}->Block(
                Name => 'WorkOrderInConditionRow',
                Data => {
                    %{$Condition},
                    %Param,
                },
            );
        }
    }
    else {
        $Self->{LayoutObject}->Block(
            Name => 'NoWorkOrderInCondition',
            Data => $WorkOrder,
        );
    }

    # start template output
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentITSMWorkOrderDelete',
        Data         => {
            %Param,
            %{$Change},
            %{$WorkOrder},
        },
    );

    # add footer
    $Output .= $Self->{LayoutObject}->Footer();

    return $Output;
}

1;
