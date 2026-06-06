import { Controller, Get, Post, Delete, Body, Param, UseGuards } from '@nestjs/common'

@Controller('/users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get(':id')
  async getById(@Param('id') id: string): Promise<User | null> {
    return this.userService.findById(id)
  }

  @Post()
  async create(@Body() dto: CreateUserDto): Promise<User> {
    return this.userService.create(dto)
  }

  @Delete(':id')
  @UseGuards(AuthGuard)
  async delete(@Param('id') id: string): Promise<void> {
    return this.userService.disable(id)
  }
}
