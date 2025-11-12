class WorkspaceInvitationMailer < ApplicationMailer
  def invite_email
    @invitation = params[:invitation]
    @workspace = @invitation.workspace
    @inviter = @invitation.inviter
    @accept_url = accept_invitation_url(@invitation.token)

    mail(
      to: @invitation.email,
      subject: "[Sales AI] #{@workspace.name} への招待"
    )
  end
end
